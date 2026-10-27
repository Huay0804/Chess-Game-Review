import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:equatable/equatable.dart';

enum GameListStatus {
  initial,
  loadingArchives,
  archives,
  loadingGames,
  loaded,
  failure,
}

class GameListState extends Equatable {
  const GameListState({
    this.status = GameListStatus.initial,
    this.username = '',
    this.archives = const [],
    this.month,
    this.games = const [],
    this.timeClass,
    this.failure,
  });

  final GameListStatus status;
  final String username;
  final List<ArchiveMonth> archives;
  final ArchiveMonth? month;
  final List<Game> games;
  final String? timeClass;
  final AppException? failure;

  List<Game> get visibleGames => timeClass == null
      ? games
      : games.where((game) => game.timeClass == timeClass).toList();

  GameListState copyWith({
    GameListStatus? status,
    List<ArchiveMonth>? archives,
    ArchiveMonth? month,
    List<Game>? games,
    AppException? failure,
    String? timeClass,
    bool resetFilter = false,
  }) => GameListState(
    status: status ?? this.status,
    username: username,
    archives: archives ?? this.archives,
    month: month ?? this.month,
    games: games ?? this.games,
    failure: failure,
    timeClass: resetFilter ? null : timeClass ?? this.timeClass,
  );

  @override
  List<Object?> get props => [
    status,
    username,
    archives,
    month,
    games,
    timeClass,
    failure,
  ];
}
