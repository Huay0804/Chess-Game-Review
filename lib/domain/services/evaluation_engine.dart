import 'package:fpdart/fpdart.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';

abstract interface class EvaluationEngine {
  Future<Either<Failure, PositionEval>> evaluate(
    String fen, {
    required int depth,
    required CancellationToken cancellation,
  });
  Future<void> dispose();
}
