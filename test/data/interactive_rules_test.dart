import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/data/services/dartchess_rules.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = DartchessRules();
  test(
    'initial position has 20 legal moves, rejects wrong side and illegal moves',
    () {
      expect(rules.legalMoves(ChessPosition.standardFen), hasLength(20));
      for (final uci in ['e7e5', 'e2e5', 'e2e2', 'e2e4q']) {
        expect(
          () => rules.playMove(ChessPosition.standardFen, uci, ply: 1),
          throwsA(isA<ParseException>()),
        );
      }
      expect(
        rules
            .playMove(ChessPosition.standardFen, 'e2e4', ply: 1)
            .after
            .squares[36],
        'P',
      );
    },
  );
  for (final (fen, uci, san) in [
    ('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1', 'e1g1', 'O-O'),
    ('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1', 'e8c8', 'O-O-O'),
    ('7k/P7/8/8/8/8/8/7K w - - 0 1', 'a7a8n', 'a8=N'),
  ]) {
    test('interactive $uci is legal and produces $san', () {
      expect(rules.legalMoves(fen), contains(uci));
      final move = rules.playMove(fen, uci, ply: 1);
      expect(move.san, san);
      expect(move.after.fen, isNot(fen));
    });
  }
  test('promotion offers four choices, not an unpromoted pawn', () {
    expect(
      rules
          .legalMoves('7k/P7/8/8/8/8/8/7K w - - 0 1')
          .where((m) => m.startsWith('a7')),
      unorderedEquals(['a7a8q', 'a7a8r', 'a7a8b', 'a7a8n']),
    );
  });
  test('en passant removes the captured pawn, just as PGN parsing does', () {
    final parsed = rules.parsePgn('1. e4 a6 2. e5 d5 3. exd6 *');
    final move = parsed.moves.last;
    expect(rules.playMove(move.fenBefore, 'e5d6', ply: 5).after, move.after);
  });
  test('pinned pieces and checkmate cannot produce illegal continuations', () {
    const pinned = '4r2k/8/8/8/8/8/4R3/4K3 w - - 0 1';
    expect(rules.legalMoves(pinned), isNot(contains('e2d2')));
    final mate = rules.parsePgn('1. f3 e5 2. g4 Qh4# *').moves.last.after;
    expect(rules.legalMoves(mate.fen), isEmpty);
  });
}
