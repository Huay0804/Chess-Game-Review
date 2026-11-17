import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';

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
    if (moves.isEmpty) return const AccuracyReport(white: null, black: null);
    // Game-level aggregation described at https://lichess.org/page/accuracy:
    // blend volatility-weighted accuracy with the harmonic mean so quiet play
    // does not wash out the critical decisions in a game.
    final chances = [
      EvaluationMath.winPercent(moves.first.before.cpWhite),
      ...moves.map((move) => EvaluationMath.winPercent(move.after.cpWhite)),
    ];
    final windowSize = (moves.length ~/ 10).clamp(2, 8);
    final weights = List<double>.generate(moves.length, (index) {
      final start = math.max(0, index + 2 - windowSize);
      final window = chances.skip(start).take(windowSize).toList();
      final mean = window.reduce((a, b) => a + b) / window.length;
      final variance =
          window.fold<double>(
            0,
            (sum, value) => sum + (value - mean) * (value - mean),
          ) /
          window.length;
      return math.sqrt(variance).clamp(.5, 12.0);
    });
    double? average(ChessSide side) {
      var count = 0;
      double weightedTotal = 0, weightTotal = 0, reciprocalTotal = 0;
      for (var i = 0; i < moves.length; i++) {
        if (moves[i].move.side != side) continue;
        final value = forLoss(moves[i].loss);
        count++;
        weightedTotal += value * weights[i];
        weightTotal += weights[i];
        // Bound the reciprocal at 1 point, as in Lichess's harmonic mean.
        // One zero-scoring move should not erase every other contribution.
        reciprocalTotal += 1 / math.max(1.0, value);
      }
      if (count == 0) return null;
      final weighted = weightedTotal / weightTotal;
      if (count == 1 || weighted == 0) return weighted;
      final harmonic = count / reciprocalTotal;
      return ((weighted + harmonic) / 2).clamp(0.0, 100.0);
    }

    return AccuracyReport(
      white: average(ChessSide.white),
      black: average(ChessSide.black),
    );
  }
}
