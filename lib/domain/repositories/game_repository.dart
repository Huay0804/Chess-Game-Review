import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';

abstract interface class GameRepository {
  /// Implementations translate infrastructure errors into [AppException].
  Future<List<ArchiveMonth>> getArchives(String username);
  Future<List<Game>> getMonthlyGames(String username, ArchiveMonth month);
}
