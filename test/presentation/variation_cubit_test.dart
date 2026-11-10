import 'dart:async';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/data/services/dartchess_rules.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/usecases/analyze_move.dart';
import 'package:chess_game_review/domain/usecases/explore_moves.dart';
import 'package:chess_game_review/presentation/bloc/variation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../support/variation_fixture.dart';

class MockAnalyze extends Mock implements AnalyzeMove {}

MoveAnalysis analysis(Move move) => MoveAnalysis(
  move: move,
  before: const PositionEval(cpWhite: 0),
  after: const PositionEval(cpWhite: -300),
  loss: .2,
  quality: MoveQuality.mistake,
  accuracy: 40,
);

void main() {
  final review = variationFixture();
  late VariationCubit cubit;
  late List<
    ({Move move, CancellationToken token, Completer<MoveAnalysis> result})
  >
  requests;
  setUpAll(() {
    registerFallbackValue(review.moves.first.move);
    registerFallbackValue(CancellationToken());
  });
  setUp(() {
    requests = [];
    final analyze = MockAnalyze();
    when(
      () => analyze(
        any(),
        depth: any(named: 'depth'),
        cancellation: any(named: 'cancellation'),
        openingLine: any(named: 'openingLine'),
        opponentLoss: any(named: 'opponentLoss'),
      ),
    ).thenAnswer((invocation) {
      final result = Completer<MoveAnalysis>();
      requests.add((
        move: invocation.positionalArguments[0] as Move,
        token: invocation.namedArguments[#cancellation] as CancellationToken,
        result: result,
      ));
      return result.future;
    });
    cubit = VariationCubit(ExploreMoves(DartchessRules()), analyze)
      ..load(review);
  });
  tearDown(() async {
    await cubit.close();
    for (final r in requests) {
      if (!r.result.isCompleted) r.result.complete(analysis(r.move));
    }
    await Future<void>.delayed(Duration.zero);
  });
  test(
    'following the original move stays on mainline without another search',
    () {
      cubit.play('e2e4');
      expect(cubit.state.basePly, 1);
      expect(cubit.state.isBranch, false);
      expect(cubit.state.analysis, review.moves.first);
      expect(requests, isEmpty);
    },
  );
  test(
    'drag creates branch immediately and does not reuse old score or quality',
    () async {
      cubit.play('d2d4');
      expect(cubit.state.move!.uci, 'd2d4');
      expect(cubit.state.busy, true);
      expect(cubit.state.analysis, isNull);
      expect(cubit.state.evaluation, isNull);
      requests.single.result.complete(analysis(requests.single.move));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.analysis!.quality, MoveQuality.mistake);
      expect(cubit.state.busy, false);
      expect(review.moves.first.move.uci, 'e2e4');
      expect(review.accuracy.white, 98);
    },
  );
  test('rapid moves cancel old search and reject its late result', () async {
    cubit.play('d2d4');
    cubit.play('d7d5');
    expect(requests.first.token.isCancelled, true);
    requests.first.result.complete(analysis(requests.first.move));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.move!.uci, 'd7d5');
    expect(cubit.state.analysis, isNull);
    requests.last.result.complete(analysis(requests.last.move));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.analysis!.move.uci, 'd7d5');
  });
  test(
    'navigation, replacement, return and late result preserve original game',
    () async {
      cubit.selectOriginal(2);
      cubit.play('f1c4');
      cubit.play('g8f6');
      cubit.navigate(1);
      expect(cubit.state.move!.uci, 'f1c4');
      cubit.play('b8c6');
      expect(cubit.state.moves.map((m) => m.uci), ['f1c4', 'b8c6']);
      cubit.returnToGame();
      expect(cubit.state.basePly, 2);
      expect(cubit.state.position, review.moves[1].move.after);
      expect(cubit.state.isBranch, false);
      for (final r in requests) {
        r.result.complete(analysis(r.move));
      }
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.analysis, review.moves[1]);
    },
  );
  test('engine error leaves position usable and retry succeeds', () async {
    cubit.play('d2d4');
    requests.last.result.completeError(const EngineException());
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.error, isA<EngineException>());
    expect(cubit.state.legalMoves, contains('d7d5'));
    final retry = cubit.retry();
    requests.last.result.complete(analysis(requests.last.move));
    await retry;
    expect(cubit.state.error, isNull);
    expect(cubit.state.analysis, isNotNull);
  });
  test('close cancels active work and tolerates its eventual result', () async {
    cubit.play('d2d4');
    await cubit.close();
    expect(requests.last.token.isCancelled, true);
    requests.last.result.complete(analysis(requests.last.move));
    await Future<void>.delayed(Duration.zero);
  });
}
