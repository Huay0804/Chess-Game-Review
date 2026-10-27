import 'package:chess_game_review/core/errors/app_exception.dart';

/// The UI boundary: await the entire operation, report errors, always clean up.
/// T can be a list of games, a list of months, or void for a stream subscription.
Future<void> runWithErrorHandling<T>(
  Future<T> Function() action, {
  required void Function(T value) onSuccess,
  required void Function(AppException error) onError,
  void Function()? onFinally,
}) async {
  try {
    final value = await action();
    onSuccess(value);
  } catch (error) {
    onError(AppException.from(error));
  } finally {
    onFinally?.call();
  }
}
