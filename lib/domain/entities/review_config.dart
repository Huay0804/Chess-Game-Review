import 'package:injectable/injectable.dart';

/// All review thresholds and engine settings live here. These are approximations,
/// not Chess.com's proprietary classification or accuracy algorithms.
@lazySingleton
class ReviewConfig {
  const ReviewConfig({@ignoreParam this.heuristicsEnabled = true});
  final bool heuristicsEnabled;
  static const defaultDepth = 14;
  static const minDepth = 12;
  static const maxDepth = 20;
  static const winCoefficient = 0.00368208;
  static const mateCp = 10000;
  static const accuracyScale = 103.1668;
  static const accuracyDecay = 0.04354;
  static const accuracyOffset = 3.1669;
  static const bestEpsilon = 0.0001;
  static const excellent = 0.02;
  static const good = 0.05;
  static const inaccuracy = 0.10;
  static const mistake = 0.20;
  static const opportunity = 0.20;
  static const clearWin = 0.70;
  static const uniqueMoveGap = 0.15;
  static const overwhelming = 0.90;
  static const sacrificeValue = 2;
  static const sacrificeMinimumWin = 0.50;
  static const greatMinimumWin = 0.45;
  static const missLoss = 0.10;
  static const materialValues = {
    'p': 1,
    'n': 3,
    'b': 3,
    'r': 5,
    'q': 9,
    'k': 0,
  };
}
