import 'dart:convert';
import 'dart:io';
import 'package:chess_game_review/core/errors/app_exception.dart';
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

class MockDio extends Mock implements Dio {}

void main() {
  late MockRemote remote;
  late MockClock clock;
  late GameRepositoryImpl repository;
  late Map<String, dynamic> sample;
  setUp(() {
    remote = MockRemote();
    clock = MockClock();
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
      final game = GameDto.fromChessCom(sample).toEntity();
      expect(game.white.username, (sample['white'] as Map)['username']);
      expect(game.white.rating, 1633);
      expect(game.white.result, 'win');
      expect(game.black.username, 'erik');
      expect(game.black.rating, 1920);
      expect(game.black.result, 'resigned');
      expect(game.url, 'https://www.chess.com/game/daily/29099782');
      expect(game.timeClass, 'daily');
      expect(game.timeControl, '1/259200');
      expect(game.rated, isTrue);
      expect(game.rules, 'chess');
      expect(
        game.endTime.millisecondsSinceEpoch,
        (sample['end_time'] as num) * 1000,
      );
      expect(game.endTime.isUtc, isTrue);
      expect(game.pgn, contains('[Event'));
      expect(game.finalFen, sample['fen']);
      expect(
        game.publishedWhiteAccuracy,
        (sample['accuracies'] as Map?)?['white'],
      );
      sample.remove('accuracies');
      sample.remove('rules');
      final withoutOptionalFields = GameDto.fromChessCom(sample).toEntity();
      expect(withoutOptionalFields.publishedWhiteAccuracy, isNull);
      expect(withoutOptionalFields.publishedBlackAccuracy, isNull);
      expect(withoutOptionalFields.rules, 'chess');
      sample['accuracies'] = {'white': 91, 'black': 83.5};
      final withAccuracies = GameDto.fromChessCom(sample).toEntity();
      expect(withAccuracies.publishedWhiteAccuracy, 91.0);
      expect(withAccuracies.publishedBlackAccuracy, 83.5);
    },
  );
  test('DTO preserves parsed values when the source JSON is changed', () {
    final dto = GameDto.fromChessCom(sample);
    final original = dto.toEntity();
    (sample['white'] as Map<String, dynamic>)['username'] = 'changed';
    (sample['accuracies'] as Map<String, dynamic>)['white'] = 0;
    sample['end_time'] = 0;

    expect(dto.toEntity(), original);
  });
  test(
    'Chess.com response reaches Domain through the real DataSource',
    () async {
      final dio = MockDio();
      const path = '/player/erik/games/2009/10';
      when(() => dio.get<Map<String, dynamic>>(path)).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          data: {
            'games': [sample],
          },
        ),
      );
      final repository = GameRepositoryImpl(
        ChessComRemoteDataSource(dio),
        clock,
      );

      final games = await repository.getMonthlyGames(
        ' ERIK ',
        const ArchiveMonth(2009, 10),
      );

      expect(games, hasLength(1));
      expect(games.single.white.username, 'Mainline_Novelty');
      expect(games.single.black.username, 'erik');
      expect(games.single.endTime, DateTime.utc(2009, 10, 4, 15, 38, 54));
      verify(() => dio.get<Map<String, dynamic>>(path)).called(1);
    },
  );
  test('invalid Chess.com field types still become ParseException', () async {
    final dio = MockDio();
    const path = '/player/erik/games/2009/10';
    sample['end_time'] = 'invalid';
    when(() => dio.get<Map<String, dynamic>>(path)).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        data: {
          'games': [sample],
        },
      ),
    );
    final repository = GameRepositoryImpl(ChessComRemoteDataSource(dio), clock);

    await expectLater(
      repository.getMonthlyGames('erik', const ArchiveMonth(2009, 10)),
      throwsA(isA<ParseException>()),
    );
  });
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
    404: NotFoundException,
    429: RateLimitException,
    503: ServerException,
    null: NetworkException,
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
      await expectLater(
        repository.getMonthlyGames('erik', const ArchiveMonth(2009, 10)),
        throwsA(
          isA<AppException>().having((e) => e.runtimeType, 'type', entry.value),
        ),
      );
    });
  }
  test('malformed payload becomes ParseException', () async {
    when(
      () => remote.getArchives('erik'),
    ).thenThrow(const FormatException('invalid'));
    await expectLater(
      repository.getArchives('erik'),
      throwsA(isA<ParseException>()),
    );
  });
  test('closed months are cached with a normalized username', () async {
    when(
      () => remote.getMonthlyGames('erik', 2009, 10),
    ).thenAnswer((_) async => [GameDto.fromChessCom(sample)]);
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
