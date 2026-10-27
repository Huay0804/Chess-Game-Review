import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/usecases/review_game.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../support/domain_fixtures.dart';

class MockReviewGame extends Mock implements ReviewGame {}

void main() {
  late MockReviewGame usecase;
  final report = GameReview(
    game: testGame,
    initial: testPosition('a', ChessSide.white),
    initialEval: const PositionEval(cpWhite: 0),
    moves: [testAnalysis(ChessSide.white, 0)],
    accuracy: const AccuracyReport(white: 100, black: null),
    depth: 14,
  );
  setUpAll(
    () => registerFallbackValue(
      ReviewGameParams(game: testGame, cancellation: CancellationToken()),
    ),
  );
  setUp(() => usecase = MockReviewGame());
  blocTest<ReviewBloc, ReviewState>(
    'review emits Loading, Progress and Loaded from usecase stream',
    build: () {
      when(() => usecase(any())).thenAnswer(
        (_) => Stream.fromIterable([
          const ReviewProgress(completed: 0, total: 1),

          ReviewProgress(completed: 1, total: 1, review: report),
        ]),
      );
      return ReviewBloc(usecase);
    },
    act: (bloc) => bloc.add(StartReview(testGame)),
    expect: () => [
      const ReviewLoading(),
      const ReviewInProgress(ReviewProgress(completed: 0, total: 1)),
      ReviewLoaded(report),
    ],
  );
  blocTest<ReviewBloc, ReviewState>(
    'engine failure is visible to presentation',
    build: () {
      when(
        () => usecase(any()),
      ).thenAnswer((_) => Stream.error(const EngineException()));
      return ReviewBloc(usecase);
    },
    act: (bloc) => bloc.add(StartReview(testGame)),
    expect: () => [
      const ReviewLoading(),
      const ReviewFailed(EngineException()),
    ],
  );
  test(
    'cancel signals the token and closes a live progress subscription',
    () async {
      final controller = StreamController<ReviewProgress>();
      late CancellationToken token;
      when(() => usecase(any())).thenAnswer((invocation) {
        token = (invocation.positionalArguments.single as ReviewGameParams)
            .cancellation;
        return controller.stream;
      });
      final bloc = ReviewBloc(usecase)..add(StartReview(testGame));
      await Future<void>.delayed(Duration.zero);
      final stopped = bloc.stream.firstWhere((state) => state is ReviewInitial);
      bloc.add(CancelReview());
      await stopped;
      expect(token.isCancelled, isTrue);
      await controller.close();
      await bloc.close();
    },
  );

  for (final synchronous in [false, true]) {
    blocTest<ReviewBloc, ReviewState>(
      '${synchronous ? 'sync' : 'stream'} review error is handled and releases the token',
      build: () {
        when(() => usecase(any())).thenAnswer((invocation) {
          if (synchronous) throw StateError('unexpected engine detail');
          return Stream.error(StateError('unexpected engine detail'));
        });
        return ReviewBloc(usecase);
      },
      act: (bloc) => bloc.add(StartReview(testGame)),
      expect: () => [
        const ReviewLoading(),
        const ReviewFailed(UnexpectedException()),
      ],
      verify: (_) {
        final params =
            verify(() => usecase(captureAny())).captured.single
                as ReviewGameParams;
        expect(params.cancellation.isCancelled, isTrue);
      },
    );
  }

  blocTest<ReviewBloc, ReviewState>(
    'cancelled review error returns to initial state',
    build: () {
      when(
        () => usecase(any()),
      ).thenAnswer((_) => Stream.error(const CancelledException()));
      return ReviewBloc(usecase);
    },
    act: (bloc) => bloc.add(StartReview(testGame)),
    expect: () => [const ReviewLoading(), const ReviewInitial()],
  );
  test(
    'starting another review cancels the old token; close cancels the current token',
    () async {
      final tokens = <CancellationToken>[];
      final streams = <StreamController<ReviewProgress>>[];
      when(() => usecase(any())).thenAnswer((invocation) {
        tokens.add(
          (invocation.positionalArguments.single as ReviewGameParams)
              .cancellation,
        );
        final stream = StreamController<ReviewProgress>();
        streams.add(stream);
        return stream.stream;
      });
      final bloc = ReviewBloc(usecase)..add(StartReview(testGame));
      await Future<void>.delayed(Duration.zero);
      bloc.add(StartReview(testGame, depth: 12));
      await Future<void>.delayed(Duration.zero);
      expect(tokens.length, 2);
      expect(tokens.first.isCancelled, isTrue);
      expect(tokens.last.isCancelled, isFalse);
      await bloc.close();
      expect(tokens.last.isCancelled, isTrue);
      for (final stream in streams) {
        await stream.close();
      }
    },
  );
}
