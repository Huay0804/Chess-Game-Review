import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/domain_fixtures.dart';

void main() {
  const classify = ClassifyMove(ReviewConfig(heuristicsEnabled: false));
  for (final (loss, quality) in <(double, MoveQuality)>[
    (-.1, MoveQuality.best),
    (0, MoveQuality.best),
    (.0001, MoveQuality.best),
    (.00010001, MoveQuality.excellent),
    (.02, MoveQuality.excellent),
    (.02000001, MoveQuality.good),
    (.05, MoveQuality.good),
    (.05000001, MoveQuality.inaccuracy),
    (.10, MoveQuality.inaccuracy),
    (.10000001, MoveQuality.mistake),
    (.20, MoveQuality.mistake),
    (.20000001, MoveQuality.blunder),
    (1, MoveQuality.blunder),
  ]) {
    test(
      'classification boundary $loss -> ${quality.name}',
      () => expect(classify(loss: loss), quality),
    );
  }
  test('engine best overrides search noise; book has precedence', () {
    expect(classify(loss: .3, isEngineBest: true), MoveQuality.best);
    expect(
      classify(loss: .3, isEngineBest: true, isBook: true),
      MoveQuality.book,
    );
  });
  test('Great, Brilliant and Miss are bounded, optional heuristics', () {
    const heuristic = ClassifyMove(ReviewConfig());
    expect(
      heuristic(loss: 0, isEngineBest: true, alternativeLoss: .2),
      MoveQuality.great,
    );
    expect(
      heuristic(loss: .01, isSacrifice: true, afterWin: .6),
      MoveQuality.brilliant,
    );
    expect(
      heuristic(loss: .3, beforeWin: .9, afterWin: .6, opponentLoss: .3),
      MoveQuality.miss,
    );
    expect(
      heuristic(loss: 0, isSacrifice: true, beforeWin: .95, afterWin: .95),
      MoveQuality.best,
    );
    expect(
      heuristic(loss: .01, isSacrifice: true, beforeWin: .2, afterWin: .2),
      MoveQuality.excellent,
    );
    expect(
      classify(
        loss: 0,
        isEngineBest: true,
        alternativeLoss: .2,
        isSacrifice: true,
      ),
      MoveQuality.best,
    );
  });
  test('winning chances are symmetric; improvements have zero loss', () {
    expect(EvaluationMath.winPercent(0), 50);
    expect(
      EvaluationMath.winPercent(100) + EvaluationMath.winPercent(-100),
      closeTo(100, 1e-10),
    );
    expect(EvaluationMath.loss(0, 300, ChessSide.white), 0);
    expect(EvaluationMath.loss(0, -300, ChessSide.black), 0);
    expect(EvaluationMath.loss(500, -500, ChessSide.white), greaterThan(.7));
  });
  const accuracy = CalculateAccuracy();
  test('all best moves yield approximately 100 for both sides', () {
    final report = accuracy([
      for (var i = 0; i < 10; i++) ...[
        testAnalysis(ChessSide.white, 0),
        testAnalysis(ChessSide.black, 0),
      ],
    ]);
    expect(report.white, closeTo(100, .001));
    expect(report.black, closeTo(100, .001));
  });
  test('many blunders lower only the responsible side accuracy', () {
    final report = accuracy([
      for (var i = 0; i < 10; i++) ...[
        testAnalysis(ChessSide.white, .5),
        testAnalysis(ChessSide.black, 0),
      ],
    ]);
    expect(report.white, lessThan(15));
    expect(report.black, greaterThan(99));
    expect(accuracy.forLoss(1), inInclusiveRange(0, 100));
    expect(accuracy.forLoss(-1), closeTo(100, .001));
  });
  test('an empty side has no accuracy', () {
    expect(accuracy([]).white, isNull);
    expect(accuracy([testAnalysis(ChessSide.white, 0)]).black, isNull);
  });
}
