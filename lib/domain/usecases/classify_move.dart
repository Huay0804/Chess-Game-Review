import 'dart:math' as math;

import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:injectable/injectable.dart';

@injectable
class ClassifyMove {
  const ClassifyMove(this._config);
  final ReviewConfig _config;

  /// Uses the same evidence for a recorded game and an interactive variation.
  MoveQuality forMove({
    required Move move,
    required PositionEval before,
    required PositionEval after,
    required double loss,
    required ChessRules rules,
    bool isBook = false,
    double opponentLoss = 0,
  }) {
    final beforeWin = EvaluationMath.forSide(before.cpWhite, move.side) / 100;
    final afterWin = EvaluationMath.forSide(after.cpWhite, move.side) / 100;
    final second = before.second;
    // Compare distinct alternatives from the same completed search iteration.
    final hasAlternative =
        second != null &&
        before.depth >= ReviewConfig.minDepth &&
        second.depth == before.depth &&
        second.bestMove != null &&
        before.bestMove != null &&
        second.bestMove != before.bestMove;
    final alternativeLoss = hasAlternative
        ? beforeWin - EvaluationMath.forSide(second.cpWhite, move.side) / 100
        : null;
    final material = move.before.squares.fold<int>(
      0,
      (sum, piece) => piece.toLowerCase() == 'p'
          ? sum
          : sum + (ReviewConfig.materialValues[piece.toLowerCase()] ?? 0),
    );
    final competitiveSacrifice =
        _config.heuristicsEnabled &&
        !isBook &&
        loss <= ReviewConfig.excellent &&
        afterWin >= ReviewConfig.sacrificeMinimumWin &&
        beforeWin < ReviewConfig.overwhelming &&
        hasAlternative &&
        beforeWin - alternativeLoss! < ReviewConfig.clearWin &&
        after.depth >= ReviewConfig.minDepth;
    bool mating(PositionEval evaluation, int sign) =>
        evaluation.mateWhite != null && evaluation.cpWhite * sign > 0;
    return call(
      loss: loss,
      isEngineBest: move.uci == before.bestMove,
      isBook: isBook,
      beforeWin: beforeWin,
      afterWin: afterWin,
      alternativeLoss: alternativeLoss,
      opponentLoss: opponentLoss,
      isSacrifice: competitiveSacrifice && _isSacrifice(move, after, rules),
      isEndgame: material <= ReviewConfig.endgameMaterial,
      deliversMate: move.after.isTerminal && mating(after, move.side.sign),
      allowsMate:
          mating(after, -move.side.sign) && !mating(before, -move.side.sign),
      missedMate:
          mating(before, move.side.sign) && !mating(after, move.side.sign),
    );
  }

  /// Confirm that the engine accepts a piece/exchange sacrifice, rather than
  /// relying on what the opponent happened to play in the recorded game.
  bool _isSacrifice(Move move, PositionEval after, ChessRules rules) {
    int index(String square) =>
        (8 - int.parse(square[1])) * 8 + square.codeUnitAt(0) - 97;
    if (after.pv.length < 2 || move.uci.length != 4) return false;
    final from = index(move.uci.substring(0, 2));
    final to = move.uci.substring(2, 4);
    final piece = move.before.squares[from].toLowerCase();
    if (!['n', 'b', 'r', 'q'].contains(piece)) return false;
    final capture = after.pv.first;
    if (capture.length < 4 || capture.substring(2, 4) != to) return false;
    try {
      if (rules.legalMoves(move.fenBefore).length < 2) return false;
      final reply = rules.playMove(move.fenAfter, capture, ply: move.ply + 1);
      final continuation = rules.playMove(
        reply.fenAfter,
        after.pv[1],
        ply: move.ply + 2,
      );
      int balance(ChessPosition position) =>
          (position.materialBalance - move.before.materialBalance) *
          move.side.sign;
      // An immediate recapture that restores material is an exchange.
      return balance(reply.after) <= -ReviewConfig.sacrificeValue &&
          balance(continuation.after) <= -ReviewConfig.sacrificeValue;
    } on AppException {
      // An incomplete/illegal PV supplies no sacrifice evidence.
      return false;
    }
  }

  /// Ordinary labels use expected-score loss; special labels need extra evidence.
  MoveQuality call({
    required double loss,
    bool isEngineBest = false,
    bool isBook = false,
    double? alternativeLoss,
    double beforeWin = 0.5,
    double afterWin = 0.5,
    double opponentLoss = 0,
    bool isSacrifice = false,
    bool isEndgame = false,
    bool deliversMate = false,
    bool allowsMate = false,
    bool missedMate = false,
  }) {
    final bounded = loss.clamp(0.0, 1.0);
    if (deliversMate) return MoveQuality.best;
    if (allowsMate) return MoveQuality.blunder;
    if (missedMate) {
      return _config.heuristicsEnabled ? MoveQuality.miss : MoveQuality.mistake;
    }
    if (isBook && bounded <= ReviewConfig.good) return MoveQuality.book;
    final nearBest = bounded <= ReviewConfig.excellent;
    final onlyGoodMove =
        alternativeLoss != null &&
        alternativeLoss >= ReviewConfig.uniqueMoveGap &&
        beforeWin - alternativeLoss < ReviewConfig.greatMinimumWin;
    if (_config.heuristicsEnabled) {
      if (!isEngineBest &&
          opponentLoss >= ReviewConfig.opportunity &&
          beforeWin >= ReviewConfig.clearWin &&
          afterWin < ReviewConfig.clearWin &&
          bounded >= ReviewConfig.missLoss) {
        return MoveQuality.miss;
      }
      if (isSacrifice &&
          nearBest &&
          afterWin >= ReviewConfig.sacrificeMinimumWin &&
          beforeWin < ReviewConfig.overwhelming &&
          alternativeLoss != null &&
          beforeWin - alternativeLoss < ReviewConfig.clearWin &&
          (!isEndgame || onlyGoodMove)) {
        return MoveQuality.brilliant;
      }
      if (isEngineBest &&
          nearBest &&
          onlyGoodMove &&
          afterWin >= ReviewConfig.greatMinimumWin &&
          beforeWin < ReviewConfig.overwhelming) {
        return MoveQuality.great;
      }
    }
    // Zero loss also occurs through score rounding, saturation and search noise.
    // It is not evidence that the played move was the engine's top choice.
    if (isEngineBest && nearBest) {
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
  /// Prefer candidate scores from one root search. Searching the child gives
  /// an extra ply of information and can shift even the best move's score.
  static double moveLoss(Move move, PositionEval before, PositionEval after) {
    // Terminal results and newly discovered/lost mates take precedence over
    // an earlier candidate score.
    if (move.after.isTerminal ||
        before.mateWhite != null ||
        after.mateWhite != null) {
      return loss(before.cpWhite, after.cpWhite, move.side);
    }
    if (move.uci == before.bestMove) return 0;
    final second = before.second;
    if (second != null &&
        before.depth >= ReviewConfig.minDepth &&
        second.depth == before.depth &&
        before.bestMove != null &&
        second.bestMove != before.bestMove &&
        second.bestMove == move.uci) {
      return loss(before.cpWhite, second.cpWhite, move.side);
    }
    return loss(before.cpWhite, after.cpWhite, move.side);
  }

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
