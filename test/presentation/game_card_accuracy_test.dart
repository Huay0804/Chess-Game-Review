import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/presentation/widgets/game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_layout_test.dart' show layoutReview;

void main() {
  testWidgets(
    'accuracy is optional, handles missing scores and fits narrow cards',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = layoutReview().game;
      Future<void> showCard(AccuracyReport? accuracy) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GameCard(
                  game: game,
                  username: game.white.username,
                  accuracy: accuracy,
                ),
              ),
            ),
          ),
        ),
      );
      await showCard(null);
      expect(find.text('Độ chính xác'), findsNothing);
      await showCard(const AccuracyReport(white: 81.24, black: 90.36));
      expect(find.text('Trắng: 81.2'), findsOneWidget);
      expect(find.text('Đen: 90.4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await showCard(const AccuracyReport(white: null, black: 0));
      expect(find.text('Trắng: —'), findsOneWidget);
      expect(find.text('Đen: 0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
