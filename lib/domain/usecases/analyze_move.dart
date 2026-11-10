import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/domain/services/opening_book.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:injectable/injectable.dart';

@injectable
class AnalyzeMove {
  const AnalyzeMove(
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

  Future<MoveAnalysis> call(
    Move move, {
    required int depth,
    required CancellationToken cancellation,
    List<String>? openingLine,
    double opponentLoss = 0,
  }) async {
    if (depth < ReviewConfig.minDepth || depth > ReviewConfig.maxDepth) {
      throw const EngineException(
        'Bạn hãy chọn độ sâu phân tích từ 12 đến 20.',
      );
    }
    Future<PositionEval> evaluate(ChessPosition position) async {
      if (cancellation.isCancelled) throw const CancelledException();
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
      return _engine.evaluate(
        position.fen,
        depth: depth,
        cancellation: cancellation,
      );
    }

    final before = await evaluate(move.before);
    final after = await evaluate(move.after);
    if (cancellation.isCancelled) throw const CancelledException();
    final loss = EvaluationMath.loss(before.cpWhite, after.cpWhite, move.side);
    final opening = openingLine == null ? null : _book.openingFor(openingLine);
    final second = before.second;
    return MoveAnalysis(
      move: move,
      before: before,
      after: after,
      loss: loss,
      accuracy: _accuracy.forLoss(loss),
      opening: opening,
      bestMoveSan: before.bestMove == null
          ? null
          : _rules.sanForUci(move.fenBefore, before.bestMove!),
      quality: _classify(
        loss: loss,
        isEngineBest: move.uci == before.bestMove,
        isBook: opening != null,
        beforeWin: EvaluationMath.forSide(before.cpWhite, move.side) / 100,
        afterWin: EvaluationMath.forSide(after.cpWhite, move.side) / 100,
        alternativeLoss: second == null
            ? null
            : (EvaluationMath.forSide(before.cpWhite, move.side) -
                      EvaluationMath.forSide(second.cpWhite, move.side)) /
                  100,
        opponentLoss: opponentLoss,
        // No future reply exists yet: do not invent a sacrifice/Brilliant label.
      ),
    );
  }
}
