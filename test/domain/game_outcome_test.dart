import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:flutter_test/flutter_test.dart';

GameSummary gameResult(String white, String black) => GameSummary(
  url: 'test:result',
  white: Player(username: 'Alice', rating: 1500, result: white),
  black: Player(username: 'Bob', rating: 1500, result: black),
  timeClass: 'rapid',
  timeControl: '600',
  endTime: DateTime.utc(2025),
  rated: true,
);

void main() {
  test(
    'result follows the searched player for either colour, ignoring case',
    () {
      for (final whiteWins in [true, false]) {
        final game = gameResult(
          whiteWins ? 'win' : 'resigned',
          whiteWins ? 'resigned' : 'win',
        );
        expect(
          game.outcomeOf(' ALICE '),
          whiteWins ? GameOutcome.win : GameOutcome.loss,
        );
        expect(
          game.outcomeOf('bOb'),
          whiteWins ? GameOutcome.loss : GameOutcome.win,
        );
      }
    },
  );
  test('all documented draw reasons stay draws for both players', () {
    for (final reason in [
      'agreed',
      'repetition',
      'stalemate',
      'insufficient',
      '50move',
      'timevsinsufficient',
    ]) {
      final game = gameResult(reason, reason);
      expect(game.outcomeOf('Alice'), GameOutcome.draw, reason: reason);
      expect(game.outcomeOf('Bob'), GameOutcome.draw, reason: reason);
    }
  });
  test('loss reasons are losses, including variant results', () {
    for (final reason in [
      'checkmated',
      'timeout',
      'resigned',
      'lose',
      'abandoned',
      'kingofthehill',
      'threecheck',
      'bughousepartnerlose',
    ]) {
      expect(
        gameResult(reason, 'win').outcomeOf('Alice'),
        GameOutcome.loss,
        reason: reason,
      );
      expect(
        gameResult('win', reason).outcomeOf('Bob'),
        GameOutcome.loss,
        reason: reason,
      );
    }
  });
  test('unrecognized player or result is not assumed to be a draw', () {
    expect(
      gameResult('win', 'resigned').outcomeOf('someone_else'),
      GameOutcome.unknown,
    );
    expect(
      gameResult('future_code', 'future_code').outcomeOf('Alice'),
      GameOutcome.unknown,
    );
  });
}
