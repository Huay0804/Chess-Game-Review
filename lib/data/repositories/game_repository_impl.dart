import 'package:chess_game_review/core/constants/app_config.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/core/time/app_clock.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';
import 'package:chess_game_review/data/datasources/chess_com_remote_data_source.dart';

@LazySingleton(as: GameRepository)
class GameRepositoryImpl implements GameRepository {
  GameRepositoryImpl(this._remote, this._clock);
  final ChessComRemoteDataSource _remote;
  final AppClock _clock;
  final _months = <String, List<Game>>{};

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() work) async {
    try {
      return Right(await work());
    } on DioException catch (e) {
      return Left(switch (e.response?.statusCode) {
        404 => const NotFoundFailure(),
        429 => const RateLimitFailure(),
        final int _ => const ServerFailure(),
        _ => const NetworkFailure(),
      });
    } on FormatException {
      return const Left(ParseFailure());
    } on TypeError {
      return const Left(ParseFailure());
    }
  }

  @override
  Future<Either<Failure, List<ArchiveMonth>>> getArchives(String username) =>
      _guard(() async {
        final result =
            (await _remote.getArchives(
                username.trim().toLowerCase(),
              )).map((e) => e.toEntity()).toSet().toList()
              ..sort((a, b) => b.startUtc.compareTo(a.startUtc));
        return List.unmodifiable(result);
      });

  @override
  Future<Either<Failure, List<Game>>> getMonthlyGames(
    String username,
    ArchiveMonth month,
  ) => _guard(() async {
    final normalized = username.trim().toLowerCase();
    final key = '$normalized/${month.path}';
    final cached = _months.remove(key);
    if (cached != null) {
      _months[key] = cached;
      return cached;
    }
    final games =
        (await _remote.getMonthlyGames(
            normalized,
            month.year,
            month.month,
          )).map((e) => e.toEntity()).toList()
          ..sort((a, b) => b.endTime.compareTo(a.endTime));
    final result = List<Game>.unmodifiable(games);
    if (!DateTime.utc(month.year, month.month + 1).isAfter(_clock.nowUtc())) {
      _months[key] = result;
      if (_months.length > AppConfig.maxCachedMonths) {
        _months.remove(_months.keys.first);
      }
    }
    return result;
  });
}
