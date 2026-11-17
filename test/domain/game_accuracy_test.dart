import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/domain_fixtures.dart';

void main() {
  const accuracy = CalculateAccuracy();
  List<MoveAnalysis> game({bool mirror = false, int length = 40}) {
    var cp = 0;
    return List.generate(length, (i) {
      final side = (i.isEven != mirror) ? ChessSide.white : ChessSide.black;
      final before = cp;
      if (i == 10) cp = mirror ? 900 : -900;
      final loss = EvaluationMath.loss(before, cp, side);
      return MoveAnalysis(
        move: testMove(
          testPosition('before-$i', side),
          testPosition('after-$i', side.opposite),
          ply: i + 1,
        ),
        before: PositionEval(cpWhite: before),
        after: PositionEval(cpWhite: cp),
        loss: loss,
        accuracy: accuracy.forLoss(loss),
        quality: loss > .2 ? MoveQuality.blunder : MoveQuality.best,
      );
    });
  }

  test('a critical blunder remains visible after many quiet moves', () {
    final moves = game();
    final white = moves.where((m) => m.move.side == ChessSide.white).toList();
    final arithmetic =
        white.map((m) => m.accuracy).reduce((a, b) => a + b) / white.length;
    final result = accuracy(moves);
    expect(arithmetic, greaterThan(95));
    expect(result.white, lessThan(80));
    expect(result.white, lessThan(arithmetic - 15));
    expect(result.black, closeTo(100, .001));
  });
  test(
    'changing colours preserves the score and penalizes the responsible side',
    () {
      final normal = accuracy(game());
      final mirrored = accuracy(game(mirror: true));
      expect(normal.white, closeTo(mirrored.black!, 1e-9));
      expect(normal.black, closeTo(mirrored.white!, 1e-9));
    },
  );
  test('constant move quality is unchanged by aggregation', () {
    for (final loss in [0.0, .01, .05, .2, .5, 1.0]) {
      final moves = [
        for (var i = 0; i < 30; i++)
          testAnalysis(i.isEven ? ChessSide.black : ChessSide.white, loss),
      ];
      final result = accuracy(moves);
      expect(result.white, closeTo(accuracy.forLoss(loss), 1e-9));
      expect(result.black, closeTo(accuracy.forLoss(loss), 1e-9));
    }
  });
  test('a zero score receives a bounded penalty in the harmonic mean', () {
    final result = accuracy([
      testAnalysis(ChessSide.black, 1),
      testAnalysis(ChessSide.white, 0),
      testAnalysis(ChessSide.black, 0),
    ]);
    // Equal weights: arithmetic 50; reciprocal floor gives harmonic ~1.98.
    expect(result.black, closeTo(25.99, .01));
    expect(result.white, closeTo(100, .001));
  });
  test(
    'a single analysed move keeps its score and the other side stays empty',
    () {
      for (final loss in [0.0, .1, .79, 1.0]) {
        final result = accuracy([testAnalysis(ChessSide.black, loss)]);
        expect(result.white, isNull);
        expect(result.black, closeTo(accuracy.forLoss(loss), 1e-9));
      }
      expect(accuracy([]).white, isNull);
      expect(accuracy([]).black, isNull);
    },
  );
  test('short and long games remain finite within the score range', () {
    for (final length in [1, 2, 10, 20, 80, 200]) {
      final result = accuracy(game(length: length));
      for (final value in [result.white, result.black].whereType<double>()) {
        expect(value.isFinite, isTrue);
        expect(value, inInclusiveRange(0, 100));
      }
    }
  });
}
