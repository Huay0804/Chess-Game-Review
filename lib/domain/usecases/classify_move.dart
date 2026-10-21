import 'dart:math' as math;

import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:injectable/injectable.dart';

@injectable
class ClassifyMove {
  const ClassifyMove(this._config);
  final ReviewConfig _config;

  /// Pure classifier. Heuristic labels are refinements, never authoritative.
  MoveQuality call({
    required double loss,
    bool isEngineBest = false,
    bool isBook = false,
    double? alternativeLoss,
    double beforeWin = 0.5,
    double afterWin = 0.5,
    double opponentLoss = 0,
    bool isSacrifice = false,
  }) {
    final bounded = loss.clamp(0.0, 1.0);
    if (isBook) return MoveQuality.book;
    if (_config.heuristicsEnabled) {
      if (!isEngineBest &&
          opponentLoss >= ReviewConfig.opportunity &&
          beforeWin >= ReviewConfig.clearWin &&
          bounded >= ReviewConfig.missLoss) {
        return MoveQuality.miss;
      }
      if (isSacrifice &&
          bounded <= ReviewConfig.excellent &&
          afterWin >= ReviewConfig.sacrificeMinimumWin &&
          beforeWin < ReviewConfig.overwhelming) {
        return MoveQuality.brilliant;
      }
      if (isEngineBest &&
          alternativeLoss != null &&
          alternativeLoss >= ReviewConfig.uniqueMoveGap &&
          afterWin >= ReviewConfig.greatMinimumWin &&
          beforeWin < ReviewConfig.overwhelming) {
        return MoveQuality.great;
      }
    }
    if (isEngineBest || bounded <= ReviewConfig.bestEpsilon) {
      return MoveQuality.best;
    }
    if (bounded <= ReviewConfig.excellent) return MoveQuality.excellent;
    if (bounded <= ReviewConfig.good) return MoveQuality.good;
    if (bounded <= ReviewConfig.inaccuracy) return MoveQuality.inaccuracy;
    if (bounded <= ReviewConfig.mistake) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }
}

abstract final class EvaluationMath {
  static double winPercent(num cpWhite) =>
      50 +
      50 * (2 / (1 + math.exp(-ReviewConfig.winCoefficient * cpWhite)) - 1);

  static double forSide(num cpWhite, ChessSide side) {
    final white = winPercent(cpWhite);
    return side == ChessSide.white ? white : 100 - white;
  }

  static double loss(num beforeWhite, num afterWhite, ChessSide side) =>
      ((forSide(beforeWhite, side) - forSide(afterWhite, side)) / 100).clamp(
        0.0,
        1.0,
      );
}
