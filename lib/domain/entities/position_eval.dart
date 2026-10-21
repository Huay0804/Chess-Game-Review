import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/entities/player.dart';

/// Every score exposed to Domain/Presentation is from White's point of view.
class EngineVariation extends Equatable {
  const EngineVariation({
    required this.cpWhite,
    required this.pv,
    required this.depth,
    this.mateWhite,
  });
  final int cpWhite;
  final int? mateWhite;
  final List<String> pv;
  final int depth;
  String? get bestMove => pv.isEmpty ? null : pv.first;
  @override
  List<Object?> get props => [cpWhite, mateWhite, pv, depth];
}

class PositionEval extends Equatable {
  const PositionEval({
    required this.cpWhite,
    this.mateWhite,
    this.bestMove,
    this.pv = const [],
    this.depth = 0,
    this.second,
  });
  final int cpWhite;

  /// Signed number of moves to mate; 0 means checkmate. Use cpWhite for winner.
  final int? mateWhite;
  final String? bestMove;
  final List<String> pv;
  final int depth;
  final EngineVariation? second;

  static int normalizedCp({
    required int score,
    required bool isMate,
    required ChessSide turn,
  }) {
    if (!isMate) return score * turn.sign;
    // UCI mate 0 means the side to move has already been checkmated.
    final direction = score > 0 ? 1 : -1;
    return direction *
        (ReviewConfig.mateCp - score.abs().clamp(0, ReviewConfig.mateCp ~/ 2)) *
        turn.sign;
  }

  @override
  List<Object?> get props => [cpWhite, mateWhite, bestMove, pv, depth, second];
}
