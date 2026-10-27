import 'dart:io';
import 'dart:ui' as ui;
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/injection.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/pages/game_list_page.dart';
import 'package:chess_game_review/presentation/pages/review_page.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/eval_chart.dart';
import 'package:chess_game_review/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../support/fake_game_repository.dart';
import '../support/fake_evaluation_engine.dart';

class MockGameRepository extends Mock implements GameRepository {}

void main() {
  setUp(() async {
    await configureDependencies();
    // Only tests replace these two interfaces. UseCases and Blocs still come
    // from the same generated DI graph used by the real application.
    await getIt.unregister<GameRepository>();
    await getIt.unregister<EvaluationEngine>();
    getIt.registerLazySingleton<GameRepository>(FakeGameRepository.new);
    getIt.registerLazySingleton<EvaluationEngine>(
      FakeEvaluationEngine.new,
      dispose: (engine) => engine.dispose(),
    );
  });
  tearDown(() async => getIt.reset());
  Future<void> finishReview(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final error in <Object>[
    const NetworkException(),
    const NotFoundException(),
    StateError('technical detail hidden from users'),
  ]) {
    testWidgets(
      'UI shows ${error.runtimeType} and can retry without crashing',
      (tester) async {
        final repository = MockGameRepository();
        when(
          () => repository.getArchives('erik'),
        ).thenAnswer((_) async => throw error);
        await getIt.unregister<GameRepository>();
        getIt.registerSingleton<GameRepository>(repository);
        await tester.pumpWidget(const App());
        await tester.enterText(find.byType(TextFormField), 'erik');
        await tester.tap(find.text('Tìm ván'));
        await tester.pumpAndSettle();
        expect(find.text(AppException.from(error).message), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);

        when(
          () => repository.getArchives('erik'),
        ).thenAnswer((_) async => const [ArchiveMonth(2025, 1)]);
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(find.text(AppException.from(error).message), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        expect(tester.takeException(), isNull);
        verify(() => repository.getArchives('erik')).called(2);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'widget flow with injected fakes: search, review, navigation and back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1150));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      if (const bool.fromEnvironment('CAPTURE_PREVIEW') && Platform.isWindows) {
        final fonts = '${Platform.environment['WINDIR']}/Fonts';
        for (final (family, file) in [
          ('Segoe UI', 'segoeui.ttf'),
          ('Segoe UI Symbol', 'seguisym.ttf'),
        ]) {
          final loader = FontLoader(family)
            ..addFont(
              Future.value(
                ByteData.sublistView(File('$fonts/$file').readAsBytesSync()),
              ),
            );
          await loader.load();
        }
      }
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: const App()));
      await tester.pumpAndSettle();
      final rootReviewBloc = tester
          .element(find.byType(GameListPage))
          .read<ReviewBloc>();
      await capture(tester, key, 'home');
      await tester.enterText(find.byType(TextFormField), 'demo');
      await tester.tap(find.text('Tìm ván'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('01/2025').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('vs DemoBlack'));
      await finishReview(tester);
      expect(find.byType(ChessBoard), findsOneWidget);
      expect(find.text('Tổng kết ván đấu'), findsOneWidget);
      final initial = tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .position
          .fen;
      await tester.tap(find.byTooltip('Nước tiếp'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        isNot(initial),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).lastUci,
        'e7e5',
      );
      await tester.tap(find.byTooltip('Đảo bàn cờ'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).flipped,
        isTrue,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('move-7')));
      await tester.tap(find.byKey(const ValueKey('move-7')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).lastUci,
        'h5f7',
      );
      await tester.ensureVisible(find.byType(EvalChart));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(EvalChart));
      await tester.tapAt(Offset(rect.left + 33, rect.center.dy));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        initial,
      );
      await tester.tap(find.byTooltip('Đảo bàn cờ'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'review');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('vs DemoBlack'), findsOneWidget);
      expect(rootReviewBloc.isClosed, isFalse);
      expect(rootReviewBloc.state, isA<ReviewInitial>());
      await tester.tap(find.textContaining('vs DemoBlack'));
      await finishReview(tester);
      expect(
        tester.element(find.byType(ReviewPage)).read<ReviewBloc>(),
        same(rootReviewBloc),
      );
      expect(rootReviewBloc.state, isA<ReviewLoaded>());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(rootReviewBloc.isClosed, isTrue);
    },
  );
  testWidgets('review fits a narrow window and offers depth 12..20', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final games = await getIt<GameRepository>().getMonthlyGames(
      'demo',
      const ArchiveMonth(2025, 1),
    );
    final game = games.single;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => getIt<ReviewBloc>(),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ReviewPage(game: game),
        ),
      ),
    );
    await finishReview(tester);
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Độ sâu phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Depth 12'), findsOneWidget);
    expect(find.text('Depth 20'), findsOneWidget);
    await tester.tap(find.text('Depth 12'));
    await finishReview(tester);
    expect(find.text('DEPTH 12 ▾'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
