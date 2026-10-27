import 'package:injectable/injectable.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/usecases/usecase.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';
import 'package:chess_game_review/domain/usecases/get_archives.dart';

class MonthlyGamesParams {
  const MonthlyGamesParams(this.username, this.month);
  final String username;
  final ArchiveMonth month;
}

@injectable
class GetMonthlyGames implements UseCase<List<Game>, MonthlyGamesParams> {
  GetMonthlyGames(this._repository);
  final GameRepository _repository;
  @override
  Future<List<Game>> call(MonthlyGamesParams params) async {
    final username = GetArchives.normalize(params.username);
    if (!GetArchives.isValid(username) || !params.month.isValid) {
      throw const ParseException(
        'Bạn hãy kiểm tra tên người chơi và chọn lại tháng cần xem.',
      );
    }
    return _repository.getMonthlyGames(username, params.month);
  }
}
