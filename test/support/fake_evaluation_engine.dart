import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';

/// Deterministic evaluation for widget tests, without a native process.
class FakeEvaluationEngine implements EvaluationEngine {
  @override
  Future<PositionEval> evaluate(
    String fen, {
    required int depth,
    required CancellationToken cancellation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 15));
    if (cancellation.isCancelled) throw const CancelledException();
    return PositionEval(cpWhite: 20, depth: depth);
  }

  @override
  Future<void> dispose() async {}
}
