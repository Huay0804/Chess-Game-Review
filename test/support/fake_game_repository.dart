import 'package:fpdart/fpdart.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';

/// Fixed input for widget tests; never registered by the application.
class FakeGameRepository implements GameRepository {
  static final game = Game(
    url: 'demo:scholars-mate',
    white: const Player(username: 'DemoWhite', rating: 1200, result: 'win'),
    black: const Player(
      username: 'DemoBlack',
      rating: 1200,
      result: 'checkmated',
    ),
    timeClass: 'rapid',
    timeControl: '600',
    endTime: DateTime.utc(2025, 1, 10),
    rated: false,
    finalFen: '',
    pgn:
        '[Event "Offline demonstration"]\n[Result "1-0"]\n\n1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7# 1-0',
  );
  @override
  Future<Either<Failure, List<ArchiveMonth>>> getArchives(
    String username,
  ) async => const Right([ArchiveMonth(2025, 1)]);
  @override
  Future<Either<Failure, List<Game>>> getMonthlyGames(
    String username,
    ArchiveMonth month,
  ) async => Right([game]);
}
