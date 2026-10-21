import 'dart:convert';
import 'dart:io';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/core/time/app_clock.dart';
import 'package:chess_game_review/data/datasources/chess_com_remote_data_source.dart';
import 'package:chess_game_review/data/models/archive_dto.dart';
import 'package:chess_game_review/data/models/game_dto.dart';
import 'package:chess_game_review/data/repositories/game_repository_impl.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements ChessComRemoteDataSource {}

class MockClock extends Mock implements AppClock {}

void main() {
  late MockRemote remote;
  late GameRepositoryImpl repository;
  late Map<String, dynamic> sample;
  setUp(() {
    remote = MockRemote();
    final clock = MockClock();
    when(clock.nowUtc).thenReturn(DateTime.utc(2026, 10, 17));
    repository = GameRepositoryImpl(remote, clock);
    final json =
        jsonDecode(
              File('test/fixtures/chess_com_month.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    sample = (json['games'] as List).first as Map<String, dynamic>;
  });
  test(
    'real Chess.com JSON maps players, seconds, PGN and absent accuracy',
    () {
      final game = GameDto.fromJson(sample).toEntity();
      expect(game.white.username, (sample['white'] as Map)['username']);
      expect(
        game.endTime.millisecondsSinceEpoch,
        (sample['end_time'] as num) * 1000,
      );
      expect(game.endTime.isUtc, isTrue);
      expect(game.pgn, contains('[Event'));
      expect(
        game.publishedWhiteAccuracy,
        (sample['accuracies'] as Map?)?['white'],
      );
      sample.remove('accuracies');
      expect(
        GameDto.fromJson(sample).toEntity().publishedWhiteAccuracy,
        isNull,
      );
      sample['accuracies'] = {'white': 91, 'black': 83.5};
      expect(GameDto.fromJson(sample).toEntity().publishedWhiteAccuracy, 91.0);
    },
  );
  test('archives parse and reject unexpected hosts/months', () {
    expect(
      ArchiveDto.fromUrl(
        'https://api.chess.com/pub/player/erik/games/2009/10',
      ).toEntity(),
      const ArchiveMonth(2009, 10),
    );
    expect(
      () =>
          ArchiveDto.fromUrl('https://example.org/pub/player/x/games/2009/10'),
      throwsFormatException,
    );
    expect(
      () => ArchiveDto.fromUrl(
        'https://api.chess.com/pub/player/x/games/2009/13',
      ),
      throwsFormatException,
    );
  });
  for (final entry in <int?, Type>{
    404: NotFoundFailure,
    429: RateLimitFailure,
    503: ServerFailure,
    null: NetworkFailure,
  }.entries) {
    test('HTTP ${entry.key} maps to ${entry.value}', () async {
      final options = RequestOptions(path: '/games');
      when(() => remote.getMonthlyGames('erik', 2009, 10)).thenThrow(
        DioException(
          requestOptions: options,
          response: entry.key == null
              ? null
              : Response(requestOptions: options, statusCode: entry.key),
        ),
      );
      final result = await repository.getMonthlyGames(
        'erik',
        const ArchiveMonth(2009, 10),
      );
      expect(result.fold((f) => f.runtimeType, (_) => null), entry.value);
    });
  }
  test('malformed payload becomes ParseFailure', () async {
    when(
      () => remote.getArchives('erik'),
    ).thenThrow(const FormatException('invalid'));
    expect(
      (await repository.getArchives('erik')).fold((l) => l, (_) => null),
      isA<ParseFailure>(),
    );
  });
  test('closed months are cached with a normalized username', () async {
    when(
      () => remote.getMonthlyGames('erik', 2009, 10),
    ).thenAnswer((_) async => [GameDto.fromJson(sample)]);
    final first = await repository.getMonthlyGames(
      ' ERIK ',
      const ArchiveMonth(2009, 10),
    );
    final second = await repository.getMonthlyGames(
      'erik',
      const ArchiveMonth(2009, 10),
    );
    expect(first, second);
    verify(() => remote.getMonthlyGames('erik', 2009, 10)).called(1);
  });
  test('current month is fetched again', () async {
    when(
      () => remote.getMonthlyGames('erik', 2026, 10),
    ).thenAnswer((_) async => []);
    await repository.getMonthlyGames('erik', const ArchiveMonth(2026, 10));
    await repository.getMonthlyGames('erik', const ArchiveMonth(2026, 10));
    verify(() => remote.getMonthlyGames('erik', 2026, 10)).called(2);
  });
}
