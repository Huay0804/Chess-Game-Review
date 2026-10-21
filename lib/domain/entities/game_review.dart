import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';

class GameReview extends Equatable {
  GameReview({
    required this.game,
    required this.initial,
    required this.initialEval,
    required List<MoveAnalysis> moves,
    required this.accuracy,
    required this.depth,
  }) : moves = List.unmodifiable(moves);
  final Game game;
  final ChessPosition initial;
  final PositionEval initialEval;
  final List<MoveAnalysis> moves;
  final AccuracyReport accuracy;
  final int depth;
  List<PositionEval> get timeline => [
    initialEval,
    ...moves.map((m) => m.after),
  ];
  Map<MoveQuality, int> countsFor(ChessSide side) {
    final counts = {for (final quality in MoveQuality.values) quality: 0};
    for (final analysis in moves.where((m) => m.move.side == side)) {
      counts[analysis.quality] = counts[analysis.quality]! + 1;
    }
    return Map.unmodifiable(counts);
  }

  @override
  List<Object?> get props => [
    game,
    initial,
    initialEval,
    moves,
    accuracy,
    depth,
  ];
}

class ReviewProgress extends Equatable {
  const ReviewProgress({
    required this.completed,
    required this.total,
    this.currentSan,
    this.review,
  });
  final int completed;
  final int total;
  final String? currentSan;
  final GameReview? review;
  @override
  List<Object?> get props => [completed, total, currentSan, review];
}

class AccuracyReport extends Equatable {
  const AccuracyReport({required this.white, required this.black});

  /// Null means that the side has no analyzed moves (not a fabricated 100%).
  final double? white;
  final double? black;
  double? forSide(ChessSide side) => side == ChessSide.white ? white : black;
  @override
  List<Object?> get props => [white, black];
}
