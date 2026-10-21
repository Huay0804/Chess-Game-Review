import 'dart:convert';
import 'dart:io';
import 'package:chess_game_review/data/services/dartchess_rules.dart';
import 'package:chess_game_review/data/services/small_opening_book.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = DartchessRules();
  ParsedGame parse(String pgn) =>
      rules.parsePgn(pgn).getOrElse((f) => throw StateError(f.message));
  test('PGN comments, clock and variations do not become moves', () {
    final game = parse('1. e4 {[%clk 0:09:58.5]} e5 (1... c5) 2. Nf3 *');
    expect(game.moves.map((m) => m.uci), ['e2e4', 'e7e5', 'g1f3']);
    expect(game.moves.first.clock, const Duration(milliseconds: 598500));
    expect(game.moves.first.after, game.moves[1].before);
    expect(game.initial.squares.length, 64);
    expect(game.moves[1].side, ChessSide.black);
  });
  test('castling becomes standard UCI and engine UCI converts to SAN', () {
    final game = parse('1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. O-O *');
    expect(game.moves.last.uci, 'e1g1');
    expect(rules.sanForUci(game.moves.last.fenBefore, 'e1g1'), 'O-O');
  });
  test('promotion and FEN setup are supported', () {
    final game = parse(
      '[SetUp "1"]\n[FEN "7k/P7/8/8/8/8/8/7K w - - 0 1"]\n\n1. a8=Q+ *',
    );
    expect(game.moves.single.uci, 'a7a8q');
    expect(game.moves.single.after.squares.first, 'Q');
  });
  test('en passant removes the captured pawn', () {
    final game = parse('1. e4 a6 2. e5 d5 3. exd6 *');
    expect(game.moves.last.uci, 'e5d6');
    expect(game.moves.last.after.materialBalance, 1);
  });
  test('checkmate and drawn final positions are terminal', () {
    expect(
      parse('1. f3 e5 2. g4 Qh4# 0-1').moves.last.after.outcome,
      PositionOutcome.blackWin,
    );
    expect(
      parse('[Result "1/2-1/2"]\n\n1. e4 e5 1/2-1/2').moves.last.after.outcome,
      PositionOutcome.draw,
    );
  });
  test('illegal and empty PGNs are failures', () {
    expect(rules.parsePgn('1. e5 *').isLeft(), isTrue);
    expect(rules.parsePgn('').isLeft(), isTrue);
    expect(rules.sanForUci('bad', 'a'), isNull);
  });
  test('real Chess.com PGNs parse all mainline moves', () {
    final json =
        jsonDecode(
              File('test/fixtures/chess_com_month.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final raw in json['games'] as List) {
      final game = parse((raw as Map)['pgn'] as String);
      expect(game.moves.length, greaterThan(10));
      expect(game.moves.every((m) => m.after.squares.length == 64), isTrue);
    }
  });
  test('opening book requires a complete matching prefix', () {
    final book = SmallOpeningBook();
    expect(book.openingFor(['e2e4', 'e7e5', 'g1f3']), isNotNull);
    expect(book.openingFor(['a2a3', 'e7e5', 'g1f3']), isNull);
    expect(book.openingFor([]), isNull);
  });
}
