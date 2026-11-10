import 'package:chess_game_review/data/services/dartchess_rules.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final rules = DartchessRules();
final parsed = rules.parsePgn('1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. O-O *');
Widget host(ChessBoard board, {bool reduceMotion = false, double size = 400}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: size, child: board),
          ),
        ),
      ),
    );
Finder square(String name) => find.byKey(ValueKey('square-$name'));
Finder piece(String name) => find.byKey(ValueKey('piece-$name'));
Finder moving(String name) => find.byKey(ValueKey('moving-$name'));
Future<void> drag(WidgetTester tester, String from, String to) async {
  final gesture = await tester.startGesture(tester.getCenter(square(from)));
  await gesture.moveBy(const Offset(0, -25));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(square(to)));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'cancelled pointer never plays a move, even over a legal square',
    (tester) async {
      String? played;
      await tester.pumpWidget(
        host(
          ChessBoard(
            position: parsed.initial,
            legalMoves: rules.legalMoves(parsed.initial.fen),
            onMove: (uci) => played = uci,
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(square('e2')));
      await gesture.moveTo(tester.getCenter(square('e4')));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(played, isNull);
      expect(piece('e2'), findsOneWidget);
    },
  );
  testWidgets(
    'drop outside returns home and flipping during drag cancels the move',
    (tester) async {
      String? played;
      Widget board(bool flipped) => host(
        ChessBoard(
          position: parsed.initial,
          flipped: flipped,
          legalMoves: rules.legalMoves(parsed.initial.fen),
          onMove: (uci) => played = uci,
        ),
      );
      await tester.pumpWidget(board(false));
      var gesture = await tester.startGesture(tester.getCenter(square('e2')));
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(played, isNull);
      expect(piece('e2'), findsOneWidget);
      gesture = await tester.startGesture(tester.getCenter(square('e2')));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await tester.pumpWidget(board(true));
      await gesture.moveTo(tester.getCenter(square('e4')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(played, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancelling promotion leaves the pawn draggable', (tester) async {
    final initial = rules
        .parsePgn('[FEN "7k/P7/8/8/8/8/8/7K w - - 0 1"]\n\n1. a8=Q+ *')
        .initial;
    String? played;
    await tester.pumpWidget(
      host(
        ChessBoard(
          position: initial,
          legalMoves: rules.legalMoves(initial.fen),
          onMove: (uci) => played = uci,
        ),
      ),
    );
    await drag(tester, 'a7', 'a8');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(played, isNull);
    await drag(tester, 'a7', 'a8');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xe'));
    await tester.pumpAndSettle();
    expect(played, 'a7a8r');
  });
  testWidgets(
    'next and previous slide the piece, then settle on the correct square',
    (tester) async {
      final move = parsed.moves.first;
      await tester.pumpWidget(host(ChessBoard(position: parsed.initial)));
      await tester.pumpWidget(
        host(
          ChessBoard(
            position: move.after,
            move: move,
            quality: MoveQuality.best,
          ),
        ),
      );
      expect(tester.getCenter(moving('e4')), tester.getCenter(square('e2')));
      await tester.pump(const Duration(milliseconds: 80));
      final y = tester.getCenter(moving('e4')).dy;
      expect(y, lessThan(tester.getCenter(square('e2')).dy));
      expect(y, greaterThan(tester.getCenter(square('e4')).dy));
      final badge = find.byKey(
        ValueKey('${move.after.fen}-${MoveQuality.best}'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(moving('e4'), findsOneWidget);
      expect(badge, findsNothing);
      await tester.pump(const Duration(milliseconds: 70));
      expect(moving('e4'), findsNothing);
      expect(badge, findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.getCenter(piece('e4')), tester.getCenter(square('e4')));
      await tester.pumpWidget(host(ChessBoard(position: parsed.initial)));
      expect(tester.getCenter(moving('e2')), tester.getCenter(square('e4')));
      await tester.pumpAndSettle();
      expect(piece('e2'), findsOneWidget);
    },
  );
  for (final flipped in [false, true]) {
    testWidgets('drag emits UCI with flipped=$flipped, no activation button', (
      tester,
    ) async {
      String? played;
      await tester.pumpWidget(
        host(
          ChessBoard(
            position: parsed.initial,
            flipped: flipped,
            legalMoves: rules.legalMoves(parsed.initial.fen),
            onMove: (uci) => played = uci,
          ),
        ),
      );
      await drag(tester, 'd2', 'd4');
      expect(played, 'd2d4');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('illegal drop returns the piece and does not call onMove', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      host(
        ChessBoard(
          position: parsed.initial,
          legalMoves: rules.legalMoves(parsed.initial.fen),
          onMove: (_) => called = true,
        ),
      ),
    );
    await drag(tester, 'e2', 'e5');
    expect(called, false);
    expect(moving('e2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getCenter(piece('e2')), tester.getCenter(square('e2')));
  });
  testWidgets('wrong side cannot be dragged', (tester) async {
    var called = false;
    await tester.pumpWidget(
      host(
        ChessBoard(
          position: parsed.initial,
          legalMoves: rules.legalMoves(parsed.initial.fen),
          onMove: (_) => called = true,
        ),
      ),
    );
    await drag(tester, 'e7', 'e5');
    expect(called, false);
    expect(piece('e7'), findsOneWidget);
  });
  testWidgets('promotion waits for an explicit piece selection', (
    tester,
  ) async {
    final initial = rules
        .parsePgn('[FEN "7k/P7/8/8/8/8/8/7K w - - 0 1"]\n\n1. a8=Q+ *')
        .initial;
    String? played;
    await tester.pumpWidget(
      host(
        ChessBoard(
          position: initial,
          legalMoves: rules.legalMoves(initial.fen),
          onMove: (uci) => played = uci,
        ),
      ),
    );
    await drag(tester, 'a7', 'a8');
    await tester.pumpAndSettle();
    expect(played, isNull);
    await tester.tap(find.text('Mã'));
    await tester.pumpAndSettle();
    expect(played, 'a7a8n');
  });
  testWidgets('castling animates both king and rook', (tester) async {
    final move = parsed.moves.last;
    await tester.pumpWidget(
      host(ChessBoard(position: move.before, move: parsed.moves[5])),
    );
    await tester.pumpWidget(host(ChessBoard(position: move.after, move: move)));
    expect(moving('g1'), findsOneWidget);
    expect(moving('f1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(piece('g1'), findsOneWidget);
    expect(piece('f1'), findsOneWidget);
    expect(piece('h1'), findsNothing);
  });
  testWidgets(
    'rapid selection, jumping and flipping do not queue old animations',
    (tester) async {
      await tester.pumpWidget(host(ChessBoard(position: parsed.initial)));
      for (final move in parsed.moves.take(3)) {
        await tester.pumpWidget(
          host(ChessBoard(position: move.after, move: move)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
      final last = parsed.moves.last;
      await tester.pumpWidget(
        host(ChessBoard(position: last.after, move: last)),
      );
      expect(moving('g1'), findsNothing);
      await tester.pumpWidget(
        host(ChessBoard(position: last.after, move: last, flipped: true)),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(piece('g1')), tester.getCenter(square('g1')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reduce motion skips travel; disposing active controller is safe',
    (tester) async {
      final move = parsed.moves.first;
      await tester.pumpWidget(
        host(ChessBoard(position: parsed.initial), reduceMotion: true),
      );
      await tester.pumpWidget(
        host(ChessBoard(position: move.after, move: move), reduceMotion: true),
      );
      expect(moving('e4'), findsNothing);
      expect(piece('e4'), findsOneWidget);
      await tester.pumpWidget(host(ChessBoard(position: parsed.initial)));
      await tester.pumpWidget(
        host(ChessBoard(position: move.after, move: move)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'result colors both move squares, exposes label, and clears for pending move',
    (tester) async {
      final move = parsed.moves.first;
      await tester.pumpWidget(
        host(ChessBoard(position: move.after, move: move)),
      );
      await tester.pumpWidget(
        host(
          ChessBoard(
            position: move.after,
            move: move,
            quality: MoveQuality.blunder,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['e2', 'e4']) {
        expect(
          (tester.widget<AnimatedContainer>(square(name)).decoration!
                  as BoxDecoration)
              .color,
          MoveQuality.blunder.color,
        );
      }
      expect(find.text('??'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('e4 Trắng tốt, Blunder'), findsOneWidget);
      semantics.dispose();
      final next = parsed.moves[1];
      await tester.pumpWidget(
        host(ChessBoard(position: next.after, move: next)),
      );
      expect(
        find.text('??'),
        findsNothing,
        reason: 'Do not fade the old label onto a new position',
      );
      await tester.pumpAndSettle();
      expect(find.text('??'), findsNothing);
      for (final name in ['e2', 'e4', 'e7', 'e5']) {
        expect(
          (tester.widget<AnimatedContainer>(square(name)).decoration!
                  as BoxDecoration)
              .color,
          isNot(MoveQuality.blunder.color),
        );
      }
    },
  );
  testWidgets('resizing during motion keeps pieces on the board', (
    tester,
  ) async {
    final move = parsed.moves.first;
    await tester.pumpWidget(host(ChessBoard(position: parsed.initial)));
    await tester.pumpWidget(host(ChessBoard(position: move.after, move: move)));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(
      host(ChessBoard(position: move.after, move: move), size: 240),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(piece('e4')), tester.getCenter(square('e4')));
    expect(tester.takeException(), isNull);
  });
}
