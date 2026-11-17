import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../support/domain_fixtures.dart';

class MockRules extends Mock implements ChessRules {}

void main() {
  const classify = ClassifyMove(ReviewConfig());
  for (final side in ChessSide.values) {
    test(
      'same-root candidate scores avoid child-search noise for ${side.name}',
      () {
        final move = testMove(
          testPosition('before', side),
          testPosition('after', side.opposite),
        );
        final shifted = PositionEval(cpWhite: -300 * side.sign);
        final top = PositionEval(
          cpWhite: 30 * side.sign,
          bestMove: move.uci,
          depth: 14,
        );
        expect(EvaluationMath.moveLoss(move, top, shifted), 0);
        final runnerUp = PositionEval(
          cpWhite: 30 * side.sign,
          bestMove: 'd2d4',
          depth: 14,
          second: EngineVariation(
            cpWhite: 20 * side.sign,
            pv: [move.uci],
            depth: 14,
          ),
        );
        expect(
          EvaluationMath.moveLoss(move, runnerUp, shifted),
          closeTo(EvaluationMath.loss(30, 20, ChessSide.white), 1e-10),
        );
        final stale = PositionEval(
          cpWhite: 30 * side.sign,
          bestMove: 'd2d4',
          depth: 14,
          second: EngineVariation(
            cpWhite: 20 * side.sign,
            pv: [move.uci],
            depth: 13,
          ),
        );
        expect(EvaluationMath.moveLoss(move, stale, shifted), greaterThan(.2));
        final mate = PositionEval(
          cpWhite: -9995 * side.sign,
          mateWhite: -5 * side.sign,
        );
        expect(EvaluationMath.moveLoss(move, top, mate), greaterThan(.5));
      },
    );
  }
  test(
    'zero loss from saturation or an improving search is not proof of Best',
    () {
      for (final side in ChessSide.values) {
        for (final (before, after) in [
          (2500, 1800),
          (-2500, -3000),
          (0, 100),
        ]) {
          final loss = EvaluationMath.loss(
            before * side.sign,
            after * side.sign,
            side,
          );
          expect(classify(loss: loss), MoveQuality.excellent);
        }
      }
    },
  );
  test('a large alternative gap alone does not make a move Great', () {
    expect(
      classify(
        loss: 0,
        isEngineBest: true,
        beforeWin: .85,
        afterWin: .85,
        alternativeLoss: .2,
      ),
      MoveQuality.best,
    );
    expect(
      classify(loss: .25, isEngineBest: true, alternativeLoss: .3),
      MoveQuality.blunder,
    );
  });
  test(
    'Miss requires giving up the winning opportunity, not just some advantage',
    () {
      expect(
        classify(loss: .12, beforeWin: .85, afterWin: .73, opponentLoss: .3),
        MoveQuality.mistake,
      );
      expect(
        classify(loss: .25, beforeWin: .85, afterWin: .60, opponentLoss: .3),
        MoveQuality.miss,
      );
      expect(
        classify(loss: .25, beforeWin: .85, afterWin: .60, opponentLoss: 0),
        MoveQuality.blunder,
      );
    },
  );
  test('a sacrifice with another winning option is not Brilliant', () {
    expect(
      classify(
        loss: 0,
        isEngineBest: true,
        isSacrifice: true,
        beforeWin: .85,
        afterWin: .85,
        alternativeLoss: .1,
      ),
      MoveQuality.best,
    );
  });
  test('endgame sacrifice must be the only good move', () {
    expect(
      classify(
        loss: 0,
        isEngineBest: true,
        isSacrifice: true,
        isEndgame: true,
        beforeWin: .6,
        afterWin: .6,
        alternativeLoss: .05,
      ),
      MoveQuality.best,
    );
    expect(
      classify(
        loss: 0,
        isEngineBest: true,
        isSacrifice: true,
        isEndgame: true,
        beforeWin: .6,
        afterWin: .6,
        alternativeLoss: .3,
      ),
      MoveQuality.brilliant,
    );
  });

  for (final side in ChessSide.values) {
    group('${side.name} engine evidence', () {
      late MockRules rules;
      late Move move;
      ChessPosition position(String fen, int material, {bool before = false}) {
        final squares = List.filled(64, '');
        squares[before ? 35 : 28] = side == ChessSide.white ? 'N' : 'n';
        return ChessPosition(
          fen: fen,
          turn: before ? side : side.opposite,
          squares: squares,
          materialBalance: material * side.sign,
        );
      }

      PositionEval evaluation({
        int depth = 14,
        int secondDepth = 14,
        String secondMove = 'd4f5',
        bool withSecond = true,
        int cp = 0,
      }) => PositionEval(
        cpWhite: cp * side.sign,
        bestMove: 'd4e5',
        depth: depth,
        second: !withSecond
            ? null
            : EngineVariation(
                cpWhite: -500 * side.sign,
                depth: secondDepth,
                pv: [secondMove],
              ),
      );
      PositionEval after({List<String> pv = const ['f6e5', 'a2a3']}) =>
          PositionEval(cpWhite: 0, depth: 14, pv: pv);
      MoveQuality label(PositionEval before, PositionEval after) =>
          classify.forMove(
            move: move,
            before: before,
            after: after,
            loss: 0,
            rules: rules,
          );
      setUp(() {
        rules = MockRules();
        move = Move(
          ply: 1,
          moveNumber: 1,
          san: 'Ne5',
          uci: 'd4e5',
          before: position('before', 0, before: true),
          after: position('after', 0),
        );
        when(() => rules.legalMoves('before')).thenReturn(['d4e5', 'd4f5']);
        final reply = Move(
          ply: 2,
          moveNumber: 1,
          san: 'Nxe5',
          uci: 'f6e5',
          before: move.after,
          after: position('reply', -3),
        );
        when(() => rules.playMove('after', 'f6e5', ply: 2)).thenReturn(reply);
        when(() => rules.playMove('reply', 'a2a3', ply: 3)).thenReturn(
          Move(
            ply: 3,
            moveNumber: 2,
            san: 'a3',
            uci: 'a2a3',
            before: reply.after,
            after: position('continuation', -3),
          ),
        );
      });
      test('accepted piece sacrifice with compensation earns Brilliant', () {
        expect(label(evaluation(), after()), MoveQuality.brilliant);
      });
      test('immediate equal recapture is an exchange, not a sacrifice', () {
        when(() => rules.playMove('reply', 'a2a3', ply: 3)).thenReturn(
          Move(
            ply: 3,
            moveNumber: 2,
            san: 'Qxe5',
            uci: 'd1e5',
            before: position('reply', -3),
            after: position('recapture', 0),
          ),
        );
        expect(label(evaluation(), after()), MoveQuality.great);
      });
      test('the only legal move is not a voluntary sacrifice', () {
        when(() => rules.legalMoves('before')).thenReturn(['d4e5']);
        // No genuine second legal move can exist in this position.
        expect(label(evaluation(withSecond: false), after()), MoveQuality.best);
      });
      test(
        'missing, shallow, mismatched or duplicate MultiPV gives no special award',
        () {
          for (final before in [
            evaluation(withSecond: false),
            evaluation(depth: 10, secondDepth: 10),
            evaluation(secondDepth: 13),
            evaluation(secondMove: 'd4e5'),
          ]) {
            expect(label(before, after()), MoveQuality.best);
          }
          verifyZeroInteractions(rules);
        },
      );
      test('truncated, unrelated or illegal PV is not sacrifice evidence', () {
        expect(label(evaluation(), after(pv: ['f6e5'])), MoveQuality.great);
        expect(
          label(evaluation(), after(pv: ['a7a6', 'a2a3'])),
          MoveQuality.great,
        );
        when(
          () => rules.playMove('after', 'f6e5', ply: 2),
        ).thenThrow(const ParseException());
        expect(label(evaluation(), after()), MoveQuality.great);
      });
      test(
        'mate threats override saturated loss and stale best/book flags',
        () {
          final result = classify.forMove(
            move: move,
            rules: rules,
            loss: 0,
            isBook: true,
            before: evaluation(cp: -1500),
            after: PositionEval(
              cpWhite: -9997 * side.sign,
              mateWhite: -3 * side.sign,
            ),
          );
          expect(result, MoveQuality.blunder);
          expect(
            classify.forMove(
              move: move,
              rules: rules,
              loss: 0,
              before: PositionEval(
                cpWhite: 9997 * side.sign,
                mateWhite: 3 * side.sign,
              ),
              after: PositionEval(cpWhite: 1500 * side.sign),
            ),
            MoveQuality.miss,
          );
        },
      );
    });
  }
}
