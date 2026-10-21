import 'dart:async';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/domain/services/opening_book.dart';
import 'package:chess_game_review/domain/usecases/calculate_accuracy.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:chess_game_review/domain/usecases/review_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import '../support/domain_fixtures.dart';

class MockEvaluationEngine extends Mock implements EvaluationEngine {}

class MockChessRules extends Mock implements ChessRules {}

class MockOpeningBook extends Mock implements OpeningBook {}

void main() {
  late MockEvaluationEngine engine;
  late MockChessRules rules;
  late MockOpeningBook book;
  late ReviewGame review;
  setUpAll(() => registerFallbackValue(CancellationToken()));
  setUp(() {
    engine = MockEvaluationEngine();
    rules = MockChessRules();
    book = MockOpeningBook();
    when(() => rules.sanForUci(any(), any())).thenReturn('d4');
    when(() => book.openingFor(any())).thenReturn(null);
    review = ReviewGame(
      engine,
      rules,
      book,
      const ClassifyMove(ReviewConfig(heuristicsEnabled: false)),
      const CalculateAccuracy(),
    );
  });
  void arrange(ParsedGame parsed, Map<String, PositionEval> evaluations) {
    when(() => rules.parsePgn(any())).thenReturn(Right(parsed));
    when(
      () => engine.evaluate(
        any(),
        depth: any(named: 'depth'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (invocation) async =>
          Right(evaluations[invocation.positionalArguments.first]!),
    );
  }

  Future<List<Either<Failure, ReviewProgress>>> run({
    CancellationToken? cancellation,
    int depth = 14,
  }) => review(
    ReviewGameParams(
      game: testGame,
      cancellation: cancellation ?? CancellationToken(),
      depth: depth,
    ),
  ).toList();
  GameReview completed(List<Either<Failure, ReviewProgress>> events) =>
      events.last.getOrElse((f) => throw StateError(f.message)).review!;

  for (final side in ChessSide.values) {
    test(
      'large evaluation drop is a blunder from ${side.name} perspective',
      () async {
        final before = testPosition('before', side),
            after = testPosition('after', side.opposite);
        arrange(ParsedGame(initial: before, moves: [testMove(before, after)]), {
          'before': PositionEval(cpWhite: 500 * side.sign, bestMove: 'd2d4'),
          'after': PositionEval(cpWhite: -500 * side.sign),
        });
        final events = await run();
        final result = completed(events);
        expect(result.moves.single.quality, MoveQuality.blunder);
        expect(result.moves.single.bestMoveSan, 'd4');
        expect(result.moves.single.loss, greaterThan(.7));
        expect(result.accuracy.forSide(side), lessThan(10));
        expect(result.countsFor(side)[MoveQuality.blunder], 1);
      },
    );
    test(
      'terminal mate won by ${side.name} skips engine and keeps sign',
      () async {
        final before = testPosition('before', side);
        final after = testPosition(
          'mate',
          side.opposite,
          outcome: side == ChessSide.white
              ? PositionOutcome.whiteWin
              : PositionOutcome.blackWin,
        );
        arrange(ParsedGame(initial: before, moves: [testMove(before, after)]), {
          'before': PositionEval(cpWhite: 500 * side.sign),
        });
        final result = completed(await run());
        expect(
          result.moves.single.after.cpWhite,
          ReviewConfig.mateCp * side.sign,
        );
        expect(result.moves.single.after.mateWhite, 0);
        expect(result.moves.single.quality, MoveQuality.best);
        verifyNever(
          () => engine.evaluate(
            'mate',
            depth: any(named: 'depth'),
            cancellation: any(named: 'cancellation'),
          ),
        );
      },
    );
  }
  test('draw terminal is zero and skips engine', () async {
    final before = testPosition('before', ChessSide.white);
    final after = testPosition(
      'draw',
      ChessSide.black,
      outcome: PositionOutcome.draw,
    );
    arrange(ParsedGame(initial: before, moves: [testMove(before, after)]), {
      'before': const PositionEval(cpWhite: 0),
    });
    expect(completed(await run()).moves.single.after.cpWhite, 0);
    verify(
      () => engine.evaluate(
        any(),
        depth: any(named: 'depth'),
        cancellation: any(named: 'cancellation'),
      ),
    ).called(1);
  });
  test(
    'emits 0..N progress, reuses adjacent/repeated FEN, completes once',
    () async {
      final a = testPosition('a', ChessSide.white),
          b = testPosition('b', ChessSide.black);
      arrange(
        ParsedGame(
          initial: a,
          moves: [
            testMove(a, b),
            testMove(b, a, ply: 2, uci: 'e7e5'),
          ],
        ),
        {
          'a': const PositionEval(cpWhite: 0),
          'b': const PositionEval(cpWhite: 0),
        },
      );
      final events = await run();
      expect(
        events.map(
          (e) => e.getOrElse((_) => throw StateError('failure')).completed,
        ),
        [0, 1, 2],
      );
      expect(
        events
            .where(
              (e) =>
                  e.getOrElse((_) => throw StateError('failure')).review !=
                  null,
            )
            .length,
        1,
      );
      expect(completed(events).moves.length, 2);
      verify(
        () => engine.evaluate(
          any(),
          depth: 14,
          cancellation: any(named: 'cancellation'),
        ),
      ).called(2);
    },
  );
  test(
    'book only matches sequences from the standard starting position',
    () async {
      final a = testPosition(ChessPosition.standardFen, ChessSide.white),
          b = testPosition('b', ChessSide.black);
      arrange(ParsedGame(initial: a, moves: [testMove(a, b)]), {
        a.fen: const PositionEval(cpWhite: 0),
        'b': const PositionEval(cpWhite: 0),
      });
      when(() => book.openingFor(['e2e4'])).thenReturn('Italian Game');
      expect(completed(await run()).moves.single.quality, MoveQuality.book);
    },
  );
  for (final throwsException in [false, true]) {
    test(
      'engine ${throwsException ? 'exception' : 'Left'} -> EngineFailure, no loaded review',
      () async {
        final a = testPosition('a', ChessSide.white),
            b = testPosition('b', ChessSide.black);
        arrange(ParsedGame(initial: a, moves: [testMove(a, b)]), {});
        final stub = when(
          () => engine.evaluate(
            any(),
            depth: any(named: 'depth'),
            cancellation: any(named: 'cancellation'),
          ),
        );
        if (throwsException) {
          stub.thenThrow(StateError('crash'));
        } else {
          stub.thenAnswer((_) async => const Left(EngineFailure()));
        }
        final events = await run();
        expect(events.length, 2);
        expect(events.last.fold((f) => f, (_) => null), isA<EngineFailure>());
      },
    );
  }
  test('parse failure never calls engine', () async {
    when(() => rules.parsePgn(any())).thenReturn(const Left(ParseFailure()));
    expect(
      (await run()).single.fold((f) => f, (_) => null),
      isA<ParseFailure>(),
    );
    verifyZeroInteractions(engine);
  });
  test(
    'cancellation during an evaluation stops before the next position',
    () async {
      final a = testPosition('a', ChessSide.white),
          b = testPosition('b', ChessSide.black);
      arrange(ParsedGame(initial: a, moves: [testMove(a, b)]), {});
      final pending = Completer<Either<Failure, PositionEval>>();
      when(
        () => engine.evaluate(
          any(),
          depth: any(named: 'depth'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) => pending.future);
      final token = CancellationToken();
      final future = run(cancellation: token);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      pending.complete(const Right(PositionEval(cpWhite: 0)));
      expect(
        (await future).last.fold((f) => f, (_) => null),
        isA<CancelledFailure>(),
      );
      verify(
        () => engine.evaluate(
          any(),
          depth: any(named: 'depth'),
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    },
  );
  test('invalid depth is rejected before parse or evaluation', () async {
    expect((await run(depth: 21)).single.isLeft(), isTrue);
    verifyZeroInteractions(rules);
    verifyZeroInteractions(engine);
  });
}
