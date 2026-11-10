import 'dart:io';
import 'dart:ui' as ui;
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/eval_chart.dart';
import 'package:chess_game_review/presentation/widgets/move_list.dart';
import 'package:chess_game_review/presentation/widgets/review_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/variation_fixture.dart';

void main() {
  for (final size in [const Size(1200, 800), const Size(360, 800)]) {
    testWidgets('overview, start, summary, resume and graph at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final review = variationFixture();
      var view = ReviewView.overview;
      var selected = 0;
      var started = false;
      final boundary = GlobalKey();
      if (const bool.fromEnvironment('CAPTURE_PREVIEW') && Platform.isWindows) {
        for (final (family, path) in [
          ('Segoe UI', '${Platform.environment['WINDIR']}/Fonts/segoeui.ttf'),
          (
            'Segoe UI Symbol',
            '${Platform.environment['WINDIR']}/Fonts/seguisym.ttf',
          ),
          (
            'MaterialIcons',
            'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          await (FontLoader(family)..addFont(
                Future.value(
                  ByteData.sublistView(File(path).readAsBytesSync()),
                ),
              ))
              .load();
        }
      }
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/$name-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              appBar: AppBar(title: const Text('Game review')),
              body: StatefulBuilder(
                builder: (context, update) => ReviewContent(
                  review: review,
                  selectedPly: selected,
                  flipped: false,
                  view: view,
                  hasStarted: started,
                  onViewChanged: (next) => update(() {
                    view = next;
                    if (next == ReviewView.moves) started = true;
                  }),
                  onSelect: (ply) => update(() => selected = ply),
                  onFlip: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSummary), findsOneWidget);
      expect(find.byType(MoveList), findsNothing);
      expect(selected, 0);
      final boardState = tester.state(find.byType(ChessBoard));
      final boardRect = tester.getRect(find.byType(ChessBoard));
      expect(
        tester.getTopLeft(find.byType(EvalChart)).dy,
        lessThan(tester.getTopLeft(find.byType(ReviewSummary)).dy),
      );
      await capture('review-overview');
      await tester.ensureVisible(find.byKey(const Key('start-review')));
      await tester.tap(find.byKey(const Key('start-review')));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.byType(ReviewSummary), findsNothing);
      expect(find.byType(MoveList), findsOneWidget);
      expect(find.byType(MoveInsight), findsOneWidget);
      expect(tester.state(find.byType(ChessBoard)), same(boardState));
      if (size.width > 1000) {
        expect(tester.getRect(find.byType(ChessBoard)), boardRect);
        expect(
          tester.getTopLeft(find.byType(MoveList)).dx,
          greaterThan(boardRect.right),
        );
        expect(
          tester.getBottomLeft(find.byType(MoveList)).dy,
          lessThan(tester.getTopLeft(find.byType(EvalChart)).dy),
        );
      }
      await capture('review-moves');
      await tester.ensureVisible(find.byTooltip('Nước tiếp'));
      await tester.tap(find.byTooltip('Nước tiếp'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      await tester.ensureVisible(find.text('Tổng kết'));
      await tester.tap(find.text('Tổng kết'));
      await tester.pumpAndSettle();
      expect(view, ReviewView.overview);
      expect(selected, 2);
      await tester.ensureVisible(find.byKey(const Key('start-review')));
      await tester.tap(find.byKey(const Key('start-review')));
      await tester.pumpAndSettle();
      expect(selected, 2);
      await tester.ensureVisible(find.text('Tổng kết'));
      await tester.tap(find.text('Tổng kết'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(EvalChart));
      await tester.pumpAndSettle();
      final chart = tester.getRect(find.byType(EvalChart));
      await tester.tapAt(Offset(chart.right - 12, chart.center.dy));
      await tester.pumpAndSettle();
      expect(view, ReviewView.moves);
      expect(selected, review.moves.length);
      expect(tester.state(find.byType(ChessBoard)), same(boardState));
      expect(tester.takeException(), isNull);
    });
  }
}
