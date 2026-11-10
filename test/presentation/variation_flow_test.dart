import 'dart:io';
import 'dart:ui' as ui;
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/injection.dart';
import 'package:chess_game_review/presentation/bloc/variation_cubit.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/review_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_evaluation_engine.dart';
import '../support/variation_fixture.dart';

void main() {
  for (final size in [const Size(1200, 1100), const Size(360, 800)]) {
    testWidgets(
      'drag -> DI -> analysis -> branch navigation -> original at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await configureDependencies();
        await getIt.unregister<EvaluationEngine>();
        getIt.registerSingleton<EvaluationEngine>(FakeEvaluationEngine());
        final exploration = getIt<VariationCubit>();
        final review = variationFixture();
        exploration.load(review);
        addTearDown(() async {
          await exploration.close();
          await getIt.reset();
        });
        final boundaryKey = GlobalKey();
        var view = ReviewView.overview;
        var started = false;
        if (const bool.fromEnvironment('CAPTURE_PREVIEW') &&
            Platform.isWindows) {
          for (final (family, filename) in [
            ('Segoe UI', 'segoeui.ttf'),
            ('Segoe UI Symbol', 'seguisym.ttf'),
          ]) {
            final loader = FontLoader(family)
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    File(
                      '${Platform.environment['WINDIR']}/Fonts/$filename',
                    ).readAsBytesSync(),
                  ),
                ),
              );
            await loader.load();
          }
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
                  ).readAsBytesSync(),
                ),
              ),
            );
          await icons.load();
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, updateView) =>
                      BlocBuilder<VariationCubit, VariationState>(
                        bloc: exploration,
                        builder: (context, state) => ReviewContent(
                          view: view,
                          hasStarted: started,
                          onViewChanged: (next) => updateView(() {
                            view = next;
                            if (next == ReviewView.moves) started = true;
                          }),
                          review: review,
                          selectedPly: state.basePly,
                          flipped: false,
                          exploration: exploration,
                          onSelect: exploration.selectOriginal,
                          onFlip: () {},
                        ),
                      ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(view, ReviewView.overview);
        final boardState = tester.state(find.byType(ChessBoard));
        Future<void> drag(String from, String to) async {
          final origin = find.byKey(ValueKey('square-$from'));
          await tester.ensureVisible(origin);
          await tester.pumpAndSettle();
          final pointer = await tester.startGesture(tester.getCenter(origin));
          await pointer.moveBy(const Offset(0, -25));
          await tester.pump();
          await pointer.moveTo(
            tester.getCenter(find.byKey(ValueKey('square-$to'))),
          );
          await tester.pump();
          await pointer.up();
          await tester.pump();
        }

        await drag('d2', 'd4');
        expect(exploration.state.move!.uci, 'd2d4');
        expect(exploration.state.isBranch, true);
        await tester.pumpAndSettle();
        expect(view, ReviewView.moves);
        expect(tester.state(find.byType(ChessBoard)), same(boardState));
        expect(exploration.state.analysis, isNotNull);
        expect(find.text('Nhánh phân tích'), findsOneWidget);
        await drag('d7', 'd5');
        await tester.pumpAndSettle();
        expect(exploration.state.moves, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Tổng kết'));
        await tester.tap(find.text('Tổng kết'));
        await tester.pumpAndSettle();
        expect(view, ReviewView.overview);
        expect(exploration.state.moves, hasLength(2));
        await tester.ensureVisible(find.byKey(const Key('start-review')));
        await tester.tap(find.byKey(const Key('start-review')));
        await tester.pumpAndSettle();
        expect(exploration.state.cursor, 2);
        expect(tester.state(find.byType(ChessBoard)), same(boardState));
        if (const bool.fromEnvironment('CAPTURE_PREVIEW') &&
            size.width > 1000) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/previews/variation.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byTooltip('Nước trước'));
        await tester.tap(find.byTooltip('Nước trước'));
        await tester.pumpAndSettle();
        expect(exploration.state.cursor, 1);
        await tester.tap(find.byTooltip('Nước tiếp'));
        await tester.pumpAndSettle();
        expect(exploration.state.cursor, 2);
        await tester.ensureVisible(find.text('Về ván gốc'));
        await tester.tap(find.text('Về ván gốc'));
        await tester.pumpAndSettle();
        expect(exploration.state.isBranch, false);
        expect(
          tester.widget<ChessBoard>(find.byType(ChessBoard)).position,
          review.initial,
        );
        expect(review.accuracy.white, 98);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
