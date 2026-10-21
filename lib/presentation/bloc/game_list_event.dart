import 'package:chess_game_review/domain/entities/archive_month.dart';

sealed class GameListEvent {}

sealed class GameListRequest extends GameListEvent {}

class SearchPlayer extends GameListRequest {
  SearchPlayer(this.username);

  final String username;
}

class SelectMonth extends GameListRequest {
  SelectMonth(this.month);

  final ArchiveMonth month;
}

class FilterTimeClass extends GameListEvent {
  FilterTimeClass(this.timeClass);

  final String? timeClass;
}
