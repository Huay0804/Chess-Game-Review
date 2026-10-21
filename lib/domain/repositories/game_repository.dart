import 'package:fpdart/fpdart.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';

abstract interface class GameRepository {
  Future<Either<Failure, List<ArchiveMonth>>> getArchives(String username);
  Future<Either<Failure, List<Game>>> getMonthlyGames(
    String username,
    ArchiveMonth month,
  );
}
