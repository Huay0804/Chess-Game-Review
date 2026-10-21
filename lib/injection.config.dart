// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:chess_game_review/core/network/dio_module.dart' as _i343;
import 'package:chess_game_review/core/time/app_clock.dart' as _i336;
import 'package:chess_game_review/data/datasources/chess_com_remote_data_source.dart'
    as _i28;
import 'package:chess_game_review/data/datasources/stockfish_data_source.dart'
    as _i64;
import 'package:chess_game_review/data/repositories/game_repository_impl.dart'
    as _i357;
import 'package:chess_game_review/data/services/dartchess_rules.dart' as _i239;
import 'package:chess_game_review/data/services/small_opening_book.dart'
    as _i776;
import 'package:chess_game_review/data/services/stockfish_evaluation_engine.dart'
    as _i991;
import 'package:chess_game_review/domain/entities/review_config.dart' as _i18;
import 'package:chess_game_review/domain/repositories/game_repository.dart'
    as _i784;
import 'package:chess_game_review/domain/services/chess_rules.dart' as _i388;
import 'package:chess_game_review/domain/services/evaluation_engine.dart'
    as _i958;
import 'package:chess_game_review/domain/services/opening_book.dart' as _i808;
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart'
    as _i289;
import 'package:chess_game_review/domain/usecases/classify_move.dart' as _i556;
import 'package:chess_game_review/domain/usecases/get_archives.dart' as _i445;
import 'package:chess_game_review/domain/usecases/get_monthly_games.dart'
    as _i870;
import 'package:chess_game_review/domain/usecases/review_game.dart' as _i434;
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart'
    as _i606;
import 'package:chess_game_review/presentation/bloc/review_bloc.dart' as _i901;
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final networkModule = _$NetworkModule();
    gh.factory<_i289.CalculateAccuracy>(() => const _i289.CalculateAccuracy());
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i336.AppClock>(() => _i336.AppClock());
    gh.lazySingleton<_i64.StockfishDataSource>(
      () => _i64.StockfishDataSource(),
    );
    gh.lazySingleton<_i18.ReviewConfig>(() => const _i18.ReviewConfig());
    gh.lazySingleton<_i388.ChessRules>(() => _i239.DartchessRules());
    gh.lazySingleton<_i808.OpeningBook>(() => _i776.SmallOpeningBook());
    gh.lazySingleton<_i28.ChessComRemoteDataSource>(
      () => _i28.ChessComRemoteDataSource(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i958.EvaluationEngine>(
      () => _i991.StockfishEvaluationEngine(gh<_i64.StockfishDataSource>()),
      dispose: (i) => i.dispose(),
    );
    gh.factory<_i556.ClassifyMove>(
      () => _i556.ClassifyMove(gh<_i18.ReviewConfig>()),
    );
    gh.lazySingleton<_i784.GameRepository>(
      () => _i357.GameRepositoryImpl(
        gh<_i28.ChessComRemoteDataSource>(),
        gh<_i336.AppClock>(),
      ),
    );
    gh.factory<_i434.ReviewGame>(
      () => _i434.ReviewGame(
        gh<_i958.EvaluationEngine>(),
        gh<_i388.ChessRules>(),
        gh<_i808.OpeningBook>(),
        gh<_i556.ClassifyMove>(),
        gh<_i289.CalculateAccuracy>(),
      ),
    );
    gh.factory<_i445.GetArchives>(
      () => _i445.GetArchives(gh<_i784.GameRepository>()),
    );
    gh.factory<_i870.GetMonthlyGames>(
      () => _i870.GetMonthlyGames(gh<_i784.GameRepository>()),
    );
    gh.factory<_i901.ReviewBloc>(
      () => _i901.ReviewBloc(gh<_i434.ReviewGame>()),
    );
    gh.factory<_i606.GameListBloc>(
      () => _i606.GameListBloc(
        gh<_i445.GetArchives>(),
        gh<_i870.GetMonthlyGames>(),
      ),
    );
    return this;
  }
}

class _$NetworkModule extends _i343.NetworkModule {}
