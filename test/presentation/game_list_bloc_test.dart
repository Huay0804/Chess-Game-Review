import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/usecases/get_archives.dart';
import 'package:chess_game_review/domain/usecases/get_monthly_games.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetArchives extends Mock implements GetArchives {}

class MockGetMonthlyGames extends Mock implements GetMonthlyGames {}

void main() {
  late MockGetArchives archives;
  late MockGetMonthlyGames monthly;
  setUpAll(
    () => registerFallbackValue(
      const MonthlyGamesParams('x', ArchiveMonth(2025, 1)),
    ),
  );
  setUp(() {
    archives = MockGetArchives();
    monthly = MockGetMonthlyGames();
  });
  blocTest<GameListBloc, GameListState>(
    'search emits loading and archives',
    build: () {
      when(
        () => archives('erik'),
      ).thenAnswer((_) async => const [ArchiveMonth(2025, 1)]);
      return GameListBloc(archives, monthly);
    },
    act: (bloc) => bloc.add(SearchPlayer('erik')),
    expect: () => [
      isA<GameListState>().having(
        (s) => s.status,
        'status',
        GameListStatus.loadingArchives,
      ),
      isA<GameListState>().having((s) => s.archives, 'archives', [
        const ArchiveMonth(2025, 1),
      ]),
    ],
  );
  blocTest<GameListBloc, GameListState>(
    'month uses usecase and reports 404',
    build: () {
      when(
        () => monthly(any()),
      ).thenAnswer((_) async => throw const NotFoundException());
      return GameListBloc(archives, monthly);
    },
    seed: () =>
        const GameListState(username: 'erik', status: GameListStatus.archives),
    act: (bloc) => bloc.add(SelectMonth(const ArchiveMonth(2025, 1))),
    expect: () => [
      isA<GameListState>().having(
        (s) => s.status,
        'loading',
        GameListStatus.loadingGames,
      ),
      isA<GameListState>().having(
        (s) => s.failure,
        'failure',
        isA<NotFoundException>(),
      ),
    ],
  );
  blocTest<GameListBloc, GameListState>(
    'month returns loaded, including empty list',
    build: () {
      when(() => monthly(any())).thenAnswer((_) async => const <Game>[]);
      return GameListBloc(archives, monthly);
    },
    seed: () => const GameListState(username: 'erik'),
    act: (bloc) => bloc.add(SelectMonth(const ArchiveMonth(2025, 1))),
    expect: () => [
      isA<GameListState>().having(
        (s) => s.status,
        'status',
        GameListStatus.loadingGames,
      ),
      isA<GameListState>().having(
        (s) => s.status,
        'status',
        GameListStatus.loaded,
      ),
    ],
  );
  test(
    'late response from an older search cannot overwrite the new player',
    () async {
      final old = Completer<List<ArchiveMonth>>();
      when(() => archives('old')).thenAnswer((_) => old.future);
      when(
        () => archives('new'),
      ).thenAnswer((_) async => const [ArchiveMonth(2025, 2)]);
      final bloc = GameListBloc(archives, monthly)..add(SearchPlayer('old'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(SearchPlayer('new'));
      await bloc.stream.firstWhere((s) => s.status == GameListStatus.archives);
      old.complete(const [ArchiveMonth(2009, 10)]);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.username, 'new');
      expect(bloc.state.archives, [const ArchiveMonth(2025, 2)]);
      await bloc.close();
    },
  );

  test(
    'late error from an older search cannot overwrite a successful search',
    () async {
      final old = Completer<List<ArchiveMonth>>();
      when(() => archives('old')).thenAnswer((_) => old.future);
      when(
        () => archives('new'),
      ).thenAnswer((_) async => const [ArchiveMonth(2025, 2)]);
      final bloc = GameListBloc(archives, monthly)..add(SearchPlayer('old'));
      addTearDown(bloc.close);
      await Future<void>.delayed(Duration.zero);
      bloc.add(SearchPlayer('new'));
      await bloc.stream.firstWhere((s) => s.status == GameListStatus.archives);
      old.completeError(const NetworkException());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.username, 'new');
      expect(bloc.state.failure, isNull);
      expect(bloc.state.status, GameListStatus.archives);
    },
  );
}
