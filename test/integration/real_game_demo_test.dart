import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/data/services/stockfish_evaluation_engine.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/domain/usecases/get_archives.dart';
import 'package:chess_game_review/domain/usecases/get_monthly_games.dart';
import 'package:chess_game_review/domain/usecases/review_game.dart';
import 'package:chess_game_review/injection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

T _value<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw TestFailure(failure.message),
  (value) => value,
);

// This test contacts Chess.com and starts real Stockfish only when requested.
// ignore_for_file: avoid_print
void main() {
  test(
    'real demo: Chess.com archives -> monthly game -> Stockfish review',
    () async {
      await configureDependencies();
      final dio = getIt<Dio>();
      final cancellation = CancellationToken();
      addTearDown(() async {
        cancellation.cancel();
        await getIt.reset();
        dio.close(force: true);
      });
      expect(getIt<EvaluationEngine>(), isA<StockfishEvaluationEngine>());
      const month = ArchiveMonth(2009, 10);
      final archives = _value(await getIt<GetArchives>()('erik'));
      expect(archives, contains(month));
      final games = _value(
        await getIt<GetMonthlyGames>()(MonthlyGamesParams('erik', month)),
      );
      final game = games.singleWhere(
        (game) => game.url == 'https://www.chess.com/game/daily/29150975',
      );
      expect(game.white.username.toLowerCase(), 'nym');
      expect(game.black.username.toLowerCase(), 'erik');
      expect(game.timeClass, 'daily');
      print('LIVE API: ${games.length} games; ${game.url}');

      final watch = Stopwatch()..start();
      GameReview? review;
      var events = 0;
      await for (final result in getIt<ReviewGame>()(
        ReviewGameParams(game: game, cancellation: cancellation, depth: 12),
      )) {
        final progress = _value(result);
        expect(progress.completed, events++);
        expect(progress.total, 32);
        if (progress.completed % 8 == 0) {
          print('STOCKFISH: ${progress.completed}/${progress.total}');
        }
        review = progress.review;
      }
      watch.stop();
      expect(events, 33); // Initial progress plus one event per ply.
      expect(review, isNotNull);
      final completed = review!;
      expect(completed.moves.length, 32);
      expect(completed.depth, 12);
      expect(completed.initialEval.depth, greaterThanOrEqualTo(12));
      expect(completed.accuracy.white, inInclusiveRange(0, 100));
      expect(completed.accuracy.black, inInclusiveRange(0, 100));
      final suggestions = completed.moves.where(
        (m) => m.quality.needsSuggestion,
      );
      expect(suggestions, isNotEmpty);
      for (final move in suggestions) {
        expect(move.bestMoveSan, isNotNull);
        print(
          'PLY ${move.move.ply}: ${move.move.san} = ${move.quality.name}; '
          'best ${move.bestMoveSan}',
        );
      }
      print(
        'REAL DEMO PASS: 32 ply; ${watch.elapsed.inSeconds}s; '
        'accuracy white ${completed.accuracy.white!.toStringAsFixed(1)}, '
        'black ${completed.accuracy.black!.toStringAsFixed(1)}',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !const bool.fromEnvironment('RUN_LIVE_DEMO')
        ? 'Opt in with --dart-define=RUN_LIVE_DEMO=true (network + Stockfish).'
        : false,
  );
}
