import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:chess_game_review/core/errors/run_with_error_handling.dart';
import 'package:chess_game_review/domain/usecases/get_archives.dart';
import 'package:chess_game_review/domain/usecases/get_monthly_games.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/presentation/bloc/game_list_event.dart';
import 'package:chess_game_review/presentation/bloc/game_list_state.dart';

export 'package:chess_game_review/presentation/bloc/game_list_event.dart';
export 'package:chess_game_review/presentation/bloc/game_list_state.dart';

@injectable
class GameListBloc extends Bloc<GameListEvent, GameListState> {
  GameListBloc(this._getArchives, this._getMonthlyGames)
    : super(const GameListState()) {
    on<GameListRequest>(_request, transformer: restartable());
    on<FilterTimeClass>(
      (event, emit) => emit(
        state.copyWith(
          timeClass: event.timeClass,
          resetFilter: event.timeClass == null,
          failure: state.failure,
        ),
      ),
    );
  }

  final GetArchives _getArchives;
  final GetMonthlyGames _getMonthlyGames;

  Future<void> _request(
    GameListRequest event,
    Emitter<GameListState> emit,
  ) async {
    switch (event) {
      case SearchPlayer():
        emit(
          GameListState(
            status: GameListStatus.loadingArchives,
            username: GetArchives.normalize(event.username),
          ),
        );
        await runWithErrorHandling(
          () => _getArchives(event.username),
          onSuccess: (archives) {
            if (emit.isDone) return;
            emit(
              state.copyWith(
                status: GameListStatus.archives,
                archives: archives,
              ),
            );
          },
          onError: (error) {
            if (emit.isDone) return;
            emit(
              state.copyWith(status: GameListStatus.failure, failure: error),
            );
          },
        );
      case SelectMonth():
        if (state.username.isEmpty) return;
        emit(
          state.copyWith(
            status: GameListStatus.loadingGames,
            month: event.month,
            games: [],
          ),
        );
        await runWithErrorHandling(
          () =>
              _getMonthlyGames(MonthlyGamesParams(state.username, event.month)),
          onSuccess: (games) {
            if (emit.isDone) return;
            emit(state.copyWith(status: GameListStatus.loaded, games: games));
          },
          onError: (error) {
            if (emit.isDone) return;
            emit(
              state.copyWith(status: GameListStatus.failure, failure: error),
            );
          },
        );
    }
  }
}
