import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
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

  Stream<ReviewProgress> call(ReviewGameParams params) async* {
    if (!params.game.canReview ||
        params.depth < ReviewConfig.minDepth ||
        params.depth > ReviewConfig.maxDepth) {
      throw const ParseException(
        'Bạn hãy chọn ván cờ tiêu chuẩn và độ sâu phân tích từ 12 đến 20.',
      );
    }
    if (params.cancellation.isCancelled) {
      throw const CancelledException();
    }
    ParsedGame parsed;
    try {
      parsed = _rules.parsePgn(params.game.pgn);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ParseException();
    }
    final total = parsed.moves.length;
    if (total == 0) {
      throw const ParseException(
        'Ván cờ này chưa có nước đi để phân tích. Bạn hãy chọn ván khác.',
      );
    }
    yield ReviewProgress(completed: 0, total: total);

    final cache = <String, PositionEval>{};
    Future<PositionEval> evaluate(ChessPosition position) async {
      if (params.cancellation.isCancelled) {
        throw const CancelledException();
      }
      // Terminal status may depend on the PGN result, so check it before FEN cache.
      if (position.isTerminal) {
        return switch (position.outcome) {
          PositionOutcome.whiteWin => const PositionEval(
            cpWhite: ReviewConfig.mateCp,
            mateWhite: 0,
          ),
          PositionOutcome.blackWin => const PositionEval(
            cpWhite: -ReviewConfig.mateCp,
            mateWhite: 0,
          ),
          _ => const PositionEval(cpWhite: 0),
        };
      }
      final key = '${params.depth}|${position.fen}';
      if (cache.containsKey(key)) return cache[key]!;
      try {
        final result = await _engine.evaluate(
          position.fen,
          depth: params.depth,
          cancellation: params.cancellation,
        );
        if (params.cancellation.isCancelled) {
          throw const CancelledException();
        }
        cache[key] = result;
        return result;
      } on AppException {
        rethrow;
      } catch (_) {
        throw const EngineException();
      }
    }

    final initial = await evaluate(parsed.initial);
    var before = initial;
    final analyses = <MoveAnalysis>[];
    final played = <String>[];
    final standardStart = parsed.initial.fen == ChessPosition.standardFen;
    for (var i = 0; i < total; i++) {
      final move = parsed.moves[i];
      final after = await evaluate(move.after);
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
      yield ReviewProgress(
        completed: i + 1,
        total: total,
        currentSan: move.san,
        review: review,
      );
    }
  }
}
