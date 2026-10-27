import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/player.dart';

class PlayerDto {
  const PlayerDto(this.username, this.rating, this.result);
  final String username;
  final int rating;
  final String result;
  factory PlayerDto.fromJson(Map<String, dynamic> json) => PlayerDto(
    json['username'] as String,
    (json['rating'] as num).toInt(),
    json['result'] as String,
  );
  Player toEntity() =>
      Player(username: username, rating: rating, result: result);
}

class GameDto {
  /// Reads Chess.com's JSON format into typed, immutable DTO fields.
  /// A generative named constructor: every call creates a new GameDto.
  GameDto.fromChessCom(Map<String, dynamic> json)
    : url = json['url'] as String,
      white = PlayerDto.fromJson(json['white'] as Map<String, dynamic>),
      black = PlayerDto.fromJson(json['black'] as Map<String, dynamic>),
      timeClass = json['time_class'] as String,
      timeControl = json['time_control'] as String,
      endTime = DateTime.fromMillisecondsSinceEpoch(
        (json['end_time'] as num).toInt() * 1000,
        isUtc: true,
      ),
      rated = json['rated'] as bool,
      rules = json['rules'] as String? ?? 'chess',
      pgn = json['pgn'] as String,
      finalFen = json['fen'] as String,
      publishedWhiteAccuracy =
          ((json['accuracies'] as Map<String, dynamic>?)?['white'] as num?)
              ?.toDouble(),
      publishedBlackAccuracy =
          ((json['accuracies'] as Map<String, dynamic>?)?['black'] as num?)
              ?.toDouble();

  final String url;
  final PlayerDto white;
  final PlayerDto black;
  final String timeClass;
  final String timeControl;
  final DateTime endTime;
  final bool rated;
  final String rules;
  final String pgn;
  final String finalFen;
  final double? publishedWhiteAccuracy;
  final double? publishedBlackAccuracy;

  Game toEntity() => Game(
    url: url,
    white: white.toEntity(),
    black: black.toEntity(),
    timeClass: timeClass,
    timeControl: timeControl,
    endTime: endTime,
    rated: rated,
    rules: rules,
    pgn: pgn,
    finalFen: finalFen,
    publishedWhiteAccuracy: publishedWhiteAccuracy,
    publishedBlackAccuracy: publishedBlackAccuracy,
  );
}
