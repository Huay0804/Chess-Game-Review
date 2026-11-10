import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/presentation/widgets/game_card.dart';
import 'package:chess_game_review/presentation/widgets/review_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/domain_fixtures.dart';

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final (result, label) in [
    ('win', 'Thắng'),
    ('resigned', 'Thua'),
    ('timevsinsufficient', 'Hòa'),
    ('unknown', 'Chưa rõ kết quả'),
  ]) {
    testWidgets(
      'match card exposes $label with large text on a narrow screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        var opened = false;
        final game = Game(
          url: 'test:game',
          white: Player(username: 'Alice', rating: 1500, result: result),
          black: const Player(
            username: 'Opponent_With_A_Long_Username',
            rating: 1500,
            result: 'win',
          ),
          timeClass: 'rapid',
          timeControl: '600',
          endTime: DateTime.utc(2025),
          rated: true,
          pgn: '',
          finalFen: '',
        );
        await tester.pumpWidget(
          host(
            GameCard(game: game, username: 'Alice', onTap: () => opened = true),
            scale: 2,
          ),
        );
        expect(find.text(label), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Alice: $label')), findsOneWidget);
        await tester.tap(find.text(label));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('technical move details are opt-in and collapse for a new move', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = testAnalysis(ChessSide.white, .3);
    MoveAnalysis analysis(int ply) => MoveAnalysis(
      move: testMove(original.move.before, original.move.after, ply: ply),
      before: const PositionEval(cpWhite: 100, pv: ['d2d4', 'd7d5']),
      after: original.after,
      loss: .3,
      accuracy: 50,
      quality: MoveQuality.miss,
      bestMoveSan: 'd4',
    );
    await tester.pumpWidget(host(MoveInsight(analysis: analysis(1)), scale: 2));
    expect(find.text('Nước tốt nhất: d4'), findsOneWidget);
    expect(find.textContaining('Biến phân tích (UCI)'), findsNothing);
    await tester.ensureVisible(find.text('Chi tiết'));
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Biến phân tích (UCI): d2d4 d7d5'), findsOneWidget);
    expect(find.text('Độ chính xác nước đi: 50.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(MoveInsight(analysis: analysis(2)), scale: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Biến phân tích (UCI)'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Về nhãn chất lượng'));
    await tester.tap(find.byTooltip('Về nhãn chất lượng'));
    await tester.pumpAndSettle();
    expect(find.text('Phân loại mang tính tham khảo.'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
