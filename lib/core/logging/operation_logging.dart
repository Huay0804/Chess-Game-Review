import 'dart:developer' as developer;

/// Reusable diagnostics for network and native engine operations.
mixin OperationLogging {
  Future<T> logOperation<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } catch (error, stackTrace) {
      developer.log(
        '$operation failed',
        name: runtimeType.toString(),
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      watch.stop();
      developer.log(
        '$operation finished in ${watch.elapsedMilliseconds} ms',
        name: runtimeType.toString(),
      );
    }
  }
}
