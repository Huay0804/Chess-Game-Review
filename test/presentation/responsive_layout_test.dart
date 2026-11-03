import 'package:bloc_test/bloc_test.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/pages/review_page.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/game_list_widgets.dart';
import 'package:chess_game_review/presentation/widgets/move_list.dart';
import 'package:chess_game_review/presentation/widgets/review_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGameListBloc extends MockBloc<GameListEvent, GameListState>
    implements GameListBloc {}

class MockReviewBloc extends MockBloc<ReviewEvent, ReviewState>
    implements ReviewBloc {}

// Layout-only fixture: long names, long SAN, three-digit move numbers and all
// quality labels. It does not represent a playable PGN or engine evaluation.
GameReview layoutReview() {
  final white = ChessPosition(
    fen: ChessPosition.standardFen,
    turn: ChessSide.white,
    squares: List.generate(64, (i) => i == 0 ? 'r' : ''),
    materialBalance: 0,
  );
  final black = ChessPosition(
    fen: 'layout-after',
    turn: ChessSide.black,
    squares: white.squares,
    materialBalance: 0,
  );
  final game = Game(
    url: 'test:layout',
    white: const Player(
      username: 'White_Player_With_A_Long_Username',
      rating: 2500,
      result: 'win',
    ),
    black: const Player(
      username: 'Black_Player_With_A_Long_Username',
      rating: 2500,
      result: 'timevsinsufficient',
    ),
    timeClass: 'rapid',
    timeControl: '600',
    endTime: DateTime.utc(2025),
    rated: true,
    pgn: 'layout fixture',
    finalFen: '',
  );
  const evaluation = PositionEval(cpWhite: -1234);
  return GameReview(
    game: game,
    initial: white,
    initialEval: evaluation,
    depth: 12,
    accuracy: const AccuracyReport(white: 100, black: 98.5),
    moves: List.generate(
      240,
      (index) => MoveAnalysis(
        move: Move(
          ply: index + 1,
          moveNumber: index ~/ 2 + 1,
          san: 'exd8=Q+',
          uci: 'e7d8q',
          before: index.isEven ? white : black,
          after: index.isEven ? black : white,
          clock: const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        before: evaluation,
        after: evaluation,
        loss: .12,
        accuracy: 87,
        quality: MoveQuality.values[index % MoveQuality.values.length],
        opening: 'Một khai cuộc có tên dài để kiểm tra nội dung xuống dòng',
      ),
    ),
  );
}

Widget testApp(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

Future<void> setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  final review = layoutReview();
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(800, 360),
    const Size(1200, 800),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('review fits $size at text scale $scale', (tester) async {
        await setSize(tester, size);
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: ReviewContent(
                review: review,
                selectedPly: 239,
                flipped: false,
                onSelect: (_) {},
                onFlip: () {},
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final board = tester.getSize(find.byType(ChessBoard));
        expect(board.width, closeTo(board.height, .01));
        await tester.ensureVisible(find.byType(MoveList));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('move-239')).hitTestable(),
          findsOneWidget,
        );
      });
    }
  }

  for (final busy in [true, false]) {
    testWidgets('short status panel scrolls to ${busy ? 'cancel' : 'retry'}', (
      tester,
    ) async {
      await setSize(tester, const Size(320, 240));
      var pressed = false;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: ReviewStatusPanel(
              state: busy
                  ? const ReviewInProgress(
                      ReviewProgress(completed: 10, total: 20),
                    )
                  : const ReviewFailed(
                      EngineException(
                        'Chưa phân tích được ván cờ này. Bạn hãy thử phân tích lại. '
                        'Nếu vẫn chưa được, hãy chọn một ván khác rồi thử lại.',
                      ),
                    ),
              onCancel: () => pressed = true,
              onRetry: () => pressed = true,
            ),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.text(busy ? 'Hủy phân tích' : 'Phân tích lại');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      expect(pressed, isTrue);
    });
  }

  testWidgets('narrow search, long error and results work with large text', (
    tester,
  ) async {
    await setSize(tester, const Size(320, 568));
    final bloc = MockGameListBloc();
    addTearDown(bloc.close);
    const month = ArchiveMonth(2025, 1);
    registerFallbackValue(SelectMonth(month));
    when(() => bloc.state).thenReturn(
      GameListState(
        status: GameListStatus.failure,
        username: review.game.white.username,
        failure: const NetworkException(),
        archives: const [month],
        month: month,
        games: [review.game],
      ),
    );
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var searched = false;
    var opened = false;
    await tester.pumpWidget(
      testApp(
        BlocProvider<GameListBloc>.value(
          value: bloc,
          child: Scaffold(
            body: GameListBody(
              usernameController: controller,
              formKey: GlobalKey<FormState>(),
              onSearch: () => searched = true,
              onReview: (_) => opened = true,
            ),
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = find
        .descendant(
          of: find.byType(GameListBody),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byType(TextFormField),
      200,
      scrollable: list,
    );
    await tester.enterText(find.byType(TextFormField), 'erik');
    await tester.ensureVisible(find.text('Tìm ván'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm ván'));
    expect(searched, isTrue);
    await tester.scrollUntilVisible(
      find.text('Thử lại'),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    verify(
      () => bloc.add(
        any(
          that: isA<SelectMonth>().having(
            (event) => event.month,
            'month',
            month,
          ),
        ),
      ),
    ).called(1);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(month.label).last);
    await tester.pumpAndSettle();
    final game = find.textContaining('vs ${review.game.black.username}');
    await tester.scrollUntilVisible(game, 200, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(game);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'move list keeps late selection visible after resize and text scaling',
    (tester) async {
      await setSize(tester, const Size(700, 500));
      var selected = 1;
      var scale = 1.0;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return testApp(
              Scaffold(
                body: MoveList(
                  moves: review.moves,
                  selectedPly: selected,
                  onSelect: (ply) => update(() => selected = ply),
                ),
              ),
              scale: scale,
            );
          },
        ),
      );
      update(() => selected = 220);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('move-220')).hitTestable(),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(320, 500));
      update(() => scale = 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('move-220')).hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('move-221')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('move-221')));
      await tester.pumpAndSettle();
      expect(selected, 221);
      update(() => selected = 0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('move-1')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'review page preserves selected move and flip across the breakpoint',
    (tester) async {
      await setSize(tester, const Size(1200, 800));
      final bloc = MockReviewBloc();
      addTearDown(bloc.close);
      when(() => bloc.state).thenReturn(ReviewLoaded(review));
      when(() => bloc.isClosed).thenReturn(false);
      await tester.pumpWidget(
        testApp(
          BlocProvider<ReviewBloc>.value(
            value: bloc,
            child: ReviewPage(game: review.game),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Nước tiếp'));
      await tester.tap(find.byTooltip('Nước tiếp'));
      await tester.tap(find.byTooltip('Đảo bàn cờ'));
      await tester.pumpAndSettle();
      final fen = tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .position
          .fen;
      expect(fen, review.moves.first.move.after.fen);
      for (final width in [889.0, 890.0, 360.0, 1200.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpAndSettle();
        final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
        expect(board.position.fen, fen);
        expect(board.flipped, isTrue);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
