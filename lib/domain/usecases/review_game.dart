import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/domain/services/opening_book.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';

class ReviewGameParams {
  const ReviewGameParams({
    required this.game,
    required this.cancellation,
    this.depth = ReviewConfig.defaultDepth,
  });
  final Game game;
  final CancellationToken cancellation;
  final int depth;
}

@injectable
class ReviewGame {
  const ReviewGame(
    this._engine,
    this._rules,
    this._book,
    this._classify,
    this._accuracy,
  );
  final EvaluationEngine _engine;
  final ChessRules _rules;
  final OpeningBook _book;
  final ClassifyMove _classify;
  final CalculateAccuracy _accuracy;

  Stream<Either<Failure, ReviewProgress>> call(ReviewGameParams params) async* {
    if (!params.game.canReview ||
        params.depth < ReviewConfig.minDepth ||
        params.depth > ReviewConfig.maxDepth) {
      yield const Left(
        ParseFailure('Chỉ hỗ trợ cờ tiêu chuẩn với depth từ 12 đến 20.'),
      );
      return;
    }
    if (params.cancellation.isCancelled) {
      yield const Left(CancelledFailure());
      return;
    }
    ParsedGame parsed;
    try {
      final result = _rules.parsePgn(params.game.pgn);
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        yield Left(failure);
        return;
      }
      parsed = result.getOrElse((_) => throw StateError('Unreachable'));
    } catch (_) {
      yield const Left(ParseFailure());
      return;
    }
    final total = parsed.moves.length;
    if (total == 0) {
      yield const Left(ParseFailure('Ván cờ không có nước đi.'));
      return;
    }
    yield Right(ReviewProgress(completed: 0, total: total));

    final cache = <String, PositionEval>{};
    Future<Either<Failure, PositionEval>> evaluate(
      ChessPosition position,
    ) async {
      if (params.cancellation.isCancelled) {
        return const Left(CancelledFailure());
      }
      // Terminal status may depend on the PGN result, so check it before FEN cache.
      if (position.isTerminal) {
        return Right(switch (position.outcome) {
          PositionOutcome.whiteWin => const PositionEval(
            cpWhite: ReviewConfig.mateCp,
            mateWhite: 0,
          ),
          PositionOutcome.blackWin => const PositionEval(
            cpWhite: -ReviewConfig.mateCp,
            mateWhite: 0,
          ),
          _ => const PositionEval(cpWhite: 0),
        });
      }
      final key = '${params.depth}|${position.fen}';
      if (cache.containsKey(key)) return Right(cache[key]!);
      try {
        final result = await _engine.evaluate(
          position.fen,
          depth: params.depth,
          cancellation: params.cancellation,
        );
        if (params.cancellation.isCancelled) {
          return const Left(CancelledFailure());
        }
        result.fold((_) {}, (evaluation) => cache[key] = evaluation);
        return result;
      } catch (_) {
        return const Left(EngineFailure());
      }
    }

    final initialResult = await evaluate(parsed.initial);
    final initialFailure = initialResult.fold<Failure?>((f) => f, (_) => null);
    if (initialFailure != null) {
      yield Left(initialFailure);
      return;
    }
    final initial = initialResult.getOrElse(
      (_) => throw StateError('Unreachable'),
    );
    var before = initial;
    final analyses = <MoveAnalysis>[];
    final played = <String>[];
    final standardStart = parsed.initial.fen == ChessPosition.standardFen;
    for (var i = 0; i < total; i++) {
      final move = parsed.moves[i];
      final result = await evaluate(move.after);
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        yield Left(failure);
        return;
      }
      final after = result.getOrElse((_) => throw StateError('Unreachable'));
      final loss = EvaluationMath.loss(
        before.cpWhite,
        after.cpWhite,
        move.side,
      );
      final beforeWin = EvaluationMath.forSide(before.cpWhite, move.side) / 100;
      final afterWin = EvaluationMath.forSide(after.cpWhite, move.side) / 100;
      played.add(move.uci);
      final opening = standardStart ? _book.openingFor(played) : null;
      final second = before.second;
      final alternativeLoss = second == null
          ? null
          : (EvaluationMath.forSide(before.cpWhite, move.side) -
                    EvaluationMath.forSide(second.cpWhite, move.side)) /
                100;
      // A sacrifice usually loses material only on the opponent's next reply.
      // This one-reply heuristic cannot prove a tactical sacrifice.
      final sacrificed =
          i + 1 < total &&
          (parsed.moves[i + 1].after.materialBalance -
                      move.before.materialBalance) *
                  move.side.sign <=
              -ReviewConfig.sacrificeValue;
      final quality = _classify(
        loss: loss,
        isEngineBest: move.uci == before.bestMove,
        isBook: opening != null,
        beforeWin: beforeWin,
        afterWin: afterWin,
        alternativeLoss: alternativeLoss,
        opponentLoss: analyses.isEmpty ? 0 : analyses.last.loss,
        isSacrifice: sacrificed,
      );
      analyses.add(
        MoveAnalysis(
          move: move,
          before: before,
          after: after,
          loss: loss,
          quality: quality,
          accuracy: _accuracy.forLoss(loss),
          opening: opening,
          bestMoveSan: before.bestMove == null
              ? null
              : _rules.sanForUci(move.fenBefore, before.bestMove!),
        ),
      );
      before = after;
      final review = i + 1 == total
          ? GameReview(
              game: params.game,
              initial: parsed.initial,
              initialEval: initial,
              moves: analyses,
              accuracy: _accuracy(analyses),
              depth: params.depth,
            )
          : null;
      yield Right(
        ReviewProgress(
          completed: i + 1,
          total: total,
          currentSan: move.san,
          review: review,
        ),
      );
    }
  }
}
