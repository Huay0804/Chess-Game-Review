import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/player.dart';

@injectable
class CalculateAccuracy {
  const CalculateAccuracy();
  double forLoss(double normalizedLoss) =>
      (ReviewConfig.accuracyScale *
                  math.exp(
                    -ReviewConfig.accuracyDecay *
                        normalizedLoss.clamp(0.0, 1.0) *
                        100,
                  ) -
              ReviewConfig.accuracyOffset)
          .clamp(0.0, 100.0);

  AccuracyReport call(List<MoveAnalysis> moves) {
    double? average(ChessSide side) {
      final values = moves
          .where((m) => m.move.side == side)
          .map((m) => forLoss(m.loss))
          .toList();
      return values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
    }

    return AccuracyReport(
      white: average(ChessSide.white),
      black: average(ChessSide.black),
    );
  }
}
