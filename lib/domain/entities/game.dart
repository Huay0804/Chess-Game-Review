import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/player.dart';

class GameSummary extends Equatable {
  const GameSummary({
    required this.url,
    required this.white,
    required this.black,
    required this.timeClass,
    required this.timeControl,
    required this.endTime,
    required this.rated,
    this.rules = 'chess',
  });
  final String url;
  final Player white;
  final Player black;
  final String timeClass;
  final String timeControl;
  final DateTime endTime;
  final bool rated;
  final String rules;
  bool get canReview => rules == 'chess';
  String get result => white.result == 'win'
      ? '1–0'
      : black.result == 'win'
      ? '0–1'
      : '½–½';
  Player opponentOf(String username) {
    final normalized = username.toLowerCase();
    if (white.username.toLowerCase() == normalized) return black;
    if (black.username.toLowerCase() == normalized) return white;
    return black;
  }

  @override
  List<Object?> get props => [
    url,
    white,
    black,
    timeClass,
    timeControl,
    endTime,
    rated,
    rules,
  ];
}

class Game extends GameSummary {
  const Game({
    required super.url,
    required super.white,
    required super.black,
    required super.timeClass,
    required super.timeControl,
    required super.endTime,
    required super.rated,
    super.rules,
    required this.pgn,
    required this.finalFen,
    this.publishedWhiteAccuracy,
    this.publishedBlackAccuracy,
  });
  final String pgn;
  final String finalFen;
  final double? publishedWhiteAccuracy;
  final double? publishedBlackAccuracy;
  @override
  List<Object?> get props => [
    ...super.props,
    pgn,
    finalFen,
    publishedWhiteAccuracy,
    publishedBlackAccuracy,
  ];
}
