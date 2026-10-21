import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';

class MoveAnalysis extends Equatable {
  const MoveAnalysis({
    required this.move,
    required this.before,
    required this.after,
    required this.loss,
    required this.quality,
    required this.accuracy,
    this.bestMoveSan,
    this.opening,
  });
  final Move move;
  final PositionEval before;
  final PositionEval after;

  /// Non-negative loss of winning chances in [0, 1], from the mover's POV.
  final double loss;
  final MoveQuality quality;
  final double accuracy;
  final String? bestMoveSan;
  final String? opening;
  @override
  List<Object?> get props => [
    move,
    before,
    after,
    loss,
    quality,
    accuracy,
    bestMoveSan,
    opening,
  ];
}
