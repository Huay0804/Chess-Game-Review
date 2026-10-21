import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';
import 'package:chess_game_review/domain/usecases/get_archives.dart';
import 'package:chess_game_review/domain/usecases/get_monthly_games.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGameRepository extends Mock implements GameRepository {}

void main() {
  late MockGameRepository repository;
  setUp(() => repository = MockGameRepository());
  const month = ArchiveMonth(2025, 1);
  test(
    'GetMonthlyGames returns games through the abstract repository',
    () async {
      when(
        () => repository.getMonthlyGames('erik', month),
      ).thenAnswer((_) async => const Right(<Game>[]));
      final result = await GetMonthlyGames(repository)(
        const MonthlyGamesParams(' EriK ', month),
      );
      expect(result.getOrElse((_) => throw StateError('failure')), isEmpty);
      verify(() => repository.getMonthlyGames('erik', month)).called(1);
    },
  );
  test('404 is preserved as NotFoundFailure', () async {
    when(
      () => repository.getMonthlyGames('missing', month),
    ).thenAnswer((_) async => const Left(NotFoundFailure()));
    final result = await GetMonthlyGames(repository)(
      const MonthlyGamesParams('missing', month),
    );
    expect(result.fold((l) => l, (_) => null), isA<NotFoundFailure>());
  });
  test('invalid input never reaches repository', () async {
    expect((await GetArchives(repository)('../x')).isLeft(), isTrue);
    expect(
      (await GetMonthlyGames(repository)(
        const MonthlyGamesParams('erik', ArchiveMonth(2025, 13)),
      )).isLeft(),
      isTrue,
    );
    verifyZeroInteractions(repository);
  });
  test('GetArchives normalizes the username', () async {
    when(
      () => repository.getArchives('erik'),
    ).thenAnswer((_) async => const Right([month]));
    expect((await GetArchives(repository)(' ERIK ')).getOrElse((_) => []), [
      month,
    ]);
  });
}
