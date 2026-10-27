import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/core/errors/run_with_error_handling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic wrapper returns typed data and always finishes', () async {
    final calls = <String>[];
    await runWithErrorHandling<List<int>>(
      () async => [1, 2],
      onSuccess: (values) {
        expect(values, [1, 2]);
        calls.add('success');
      },
      onError: (_) => fail('Successful work must not report an error'),
      onFinally: () => calls.add('finally'),
    );
    expect(calls, ['success', 'finally']);
  });

  for (final asynchronous in [false, true]) {
    test(
      'wrapper catches ${asynchronous ? 'async' : 'sync'} custom exception and cleans up',
      () async {
        const original = NotFoundException();
        final calls = <String>[];
        await runWithErrorHandling<int>(
          () {
            if (asynchronous) return Future<int>.error(original);
            throw original;
          },
          onSuccess: (_) => fail('Failed work must not report success'),
          onError: (error) {
            expect(error, same(original));
            calls.add('error');
          },
          onFinally: () => calls.add('finally'),
        );
        expect(calls, ['error', 'finally']);
      },
    );
  }

  test('unexpected technical errors become a safe UI message', () async {
    await runWithErrorHandling<void>(
      () async => throw StateError('internal diagnostic details'),
      onSuccess: (_) => fail('Expected an error'),
      onError: (error) {
        expect(error, isA<UnexpectedException>());
        expect(error.message, isNot(contains('internal diagnostic details')));
        expect(error.message, isNotEmpty);
      },
    );
  });
}
