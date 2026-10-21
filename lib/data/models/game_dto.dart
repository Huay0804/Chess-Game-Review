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
  const GameDto(this.game);
  final Game game;
  factory GameDto.fromJson(Map<String, dynamic> json) {
    final accuracies = json['accuracies'] as Map<String, dynamic>?;
    return GameDto(
      Game(
        url: json['url'] as String,
        white: PlayerDto.fromJson(
          json['white'] as Map<String, dynamic>,
        ).toEntity(),
        black: PlayerDto.fromJson(
          json['black'] as Map<String, dynamic>,
        ).toEntity(),
        timeClass: json['time_class'] as String,
        timeControl: json['time_control'] as String,
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (json['end_time'] as num).toInt() * 1000,
          isUtc: true,
        ),
        rated: json['rated'] as bool,
        rules: json['rules'] as String? ?? 'chess',
        pgn: json['pgn'] as String,
        finalFen: json['fen'] as String,
        publishedWhiteAccuracy: (accuracies?['white'] as num?)?.toDouble(),
        publishedBlackAccuracy: (accuracies?['black'] as num?)?.toDouble(),
      ),
    );
  }
  Game toEntity() => game;
}
