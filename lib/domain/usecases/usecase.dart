import 'package:fpdart/fpdart.dart';
import 'package:chess_game_review/core/errors/failure.dart';

abstract interface class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}
