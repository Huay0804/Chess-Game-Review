import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/domain/services/opening_book.dart';
import 'package:chess_game_review/domain/usecases/analyze_move.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:chess_game_review/domain/usecases/explore_moves.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../support/domain_fixtures.dart';

class MockEngine extends Mock implements EvaluationEngine {}

class MockRules extends Mock implements ChessRules {}

class MockBook extends Mock implements OpeningBook {}

void main() {
  late MockEngine engine;
  late MockRules rules;
  late MockBook book;
  late AnalyzeMove analyze;
  late CancellationToken token;
  setUp(() {
    engine = MockEngine();
    rules = MockRules();
    book = MockBook();
    token = CancellationToken();
    analyze = AnalyzeMove(
      engine,
      rules,
      book,
      const ClassifyMove(ReviewConfig()),
      const CalculateAccuracy(),
    );
    when(() => rules.sanForUci(any(), any())).thenReturn('d4');
    when(() => book.openingFor(any())).thenReturn(null);
  });
  for (final side in ChessSide.values) {
    test(
      'classifies loss from $side perspective with mocked interfaces',
      () async {
        final move = testMove(
          testPosition('before', side),
          testPosition('after', side.opposite),
        );
        when(
          () => engine.evaluate('before', depth: 12, cancellation: token),
        ).thenAnswer(
          (_) async => const PositionEval(cpWhite: 0, bestMove: 'd2d4'),
        );
        when(
          () => engine.evaluate('after', depth: 12, cancellation: token),
        ).thenAnswer((_) async => PositionEval(cpWhite: -1000 * side.sign));
        final result = await analyze(move, depth: 12, cancellation: token);
        expect(result.quality, MoveQuality.blunder);
        expect(result.bestMoveSan, 'd4');
        expect(result.move, same(move));
        verify(
          () => engine.evaluate('before', depth: 12, cancellation: token),
        ).called(1);
        verify(
          () => engine.evaluate('after', depth: 12, cancellation: token),
        ).called(1);
        verifyNever(() => book.openingFor(any()));
      },
    );
  }
  test('terminal position does not start an engine search', () async {
    final move = testMove(
      testPosition('before', ChessSide.white),
      testPosition('mate', ChessSide.black, outcome: PositionOutcome.whiteWin),
    );
    when(
      () => engine.evaluate('before', depth: 12, cancellation: token),
    ).thenAnswer((_) async => const PositionEval(cpWhite: 1000));
    final result = await analyze(move, depth: 12, cancellation: token);
    expect(result.after.mateWhite, 0);
    expect(result.after.cpWhite, ReviewConfig.mateCp);
    verifyNever(() => engine.evaluate('mate', depth: 12, cancellation: token));
  });
  test('cancel between searches prevents the next search', () async {
    final move = testMove(
      testPosition('before', ChessSide.white),
      testPosition('after', ChessSide.black),
    );
    when(
      () => engine.evaluate('before', depth: 12, cancellation: token),
    ).thenAnswer((_) async {
      token.cancel();
      return const PositionEval(cpWhite: 0);
    });
    await expectLater(
      analyze(move, depth: 12, cancellation: token),
      throwsA(isA<CancelledException>()),
    );
    verifyNever(() => engine.evaluate('after', depth: 12, cancellation: token));
  });
  test('book classification uses the complete supplied line', () async {
    final move = testMove(
      testPosition('before', ChessSide.white),
      testPosition('after', ChessSide.black),
    );
    when(
      () => engine.evaluate(any(), depth: 12, cancellation: token),
    ).thenAnswer((_) async => const PositionEval(cpWhite: 0));
    when(() => book.openingFor(['e2e4'])).thenReturn('King Pawn');
    final result = await analyze(
      move,
      depth: 12,
      cancellation: token,
      openingLine: ['e2e4'],
    );
    expect(result.quality, MoveQuality.book);
    expect(result.opening, 'King Pawn');
  });
  test('invalid depth never reaches engine', () async {
    final move = testMove(
      testPosition('before', ChessSide.white),
      testPosition('after', ChessSide.black),
    );
    await expectLater(
      analyze(move, depth: 1, cancellation: token),
      throwsA(isA<EngineException>()),
    );
    verifyZeroInteractions(engine);
  });
  test(
    'ExploreMoves delegates legality and move creation to abstract rules',
    () {
      final position = testPosition('before', ChessSide.white);
      final move = testMove(position, testPosition('after', ChessSide.black));
      when(() => rules.legalMoves('before')).thenReturn(['e2e4']);
      when(() => rules.playMove('before', 'e2e4', ply: 1)).thenReturn(move);
      final explore = ExploreMoves(rules);
      expect(explore.legalMoves(position), ['e2e4']);
      expect(explore(position, 'e2e4', ply: 1), same(move));
    },
  );
}
