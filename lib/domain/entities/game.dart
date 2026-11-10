import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/player.dart';

enum GameOutcome { win, loss, draw, unknown }

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

  /// Result from the searched player's perspective, never inferred from colour.
  GameOutcome outcomeOf(String username) {
    final name = username.trim().toLowerCase();
    final player = white.username.toLowerCase() == name
        ? white
        : black.username.toLowerCase() == name
        ? black
        : null;
    if (player == null) return GameOutcome.unknown;
    return switch (player.result) {
      'win' => GameOutcome.win,
      'checkmated' ||
      'timeout' ||
      'resigned' ||
      'lose' ||
      'abandoned' ||
      'kingofthehill' ||
      'threecheck' ||
      'bughousepartnerlose' => GameOutcome.loss,
      'agreed' ||
      'repetition' ||
      'stalemate' ||
      'insufficient' ||
      '50move' ||
      'timevsinsufficient' => GameOutcome.draw,
      _ => GameOutcome.unknown,
    };
  }

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
