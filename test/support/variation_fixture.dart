import 'package:chess_game_review/data/services/dartchess_rules.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'domain_fixtures.dart';

GameReview variationFixture() {
  final parsed = DartchessRules().parsePgn(
    '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. O-O *',
  );
  const score = PositionEval(cpWhite: 10);
  return GameReview(
    game: testGame,
    initial: parsed.initial,
    initialEval: score,
    depth: 12,
    accuracy: const AccuracyReport(white: 98, black: 97),
    moves: [
      for (final move in parsed.moves)
        MoveAnalysis(
          move: move,
          before: score,
          after: score,
          loss: 0,
          quality: MoveQuality.best,
          accuracy: 100,
        ),
    ],
  );
}
