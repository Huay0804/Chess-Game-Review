import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';

abstract interface class EvaluationEngine {
  /// Throws [AppException] for invalid input, cancellation or engine failure.
  Future<PositionEval> evaluate(
    String fen, {
    required int depth,
    required CancellationToken cancellation,
  });
  Future<void> dispose();
}
