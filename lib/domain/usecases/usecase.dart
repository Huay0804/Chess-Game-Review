import 'package:chess_game_review/core/errors/app_exception.dart';

abstract interface class UseCase<T, P> {
  /// Returns T on success; completes with an [AppException] on failure.
  Future<T> call(P params);
}
