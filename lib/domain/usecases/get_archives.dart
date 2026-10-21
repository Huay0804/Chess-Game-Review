import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/usecases/usecase.dart';
import 'package:chess_game_review/domain/entities/archive_month.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';

@injectable
class GetArchives implements UseCase<List<ArchiveMonth>, String> {
  GetArchives(this._repository);
  final GameRepository _repository;
  static String normalize(String username) => username.trim().toLowerCase();
  static bool isValid(String username) =>
      RegExp(r'^[a-z0-9_-]{1,50}$').hasMatch(username);
  @override
  Future<Either<Failure, List<ArchiveMonth>>> call(String params) async {
    final username = normalize(params);
    if (!isValid(username)) {
      return const Left(
        ParseFailure(
          'Username chỉ gồm chữ, số, dấu gạch ngang hoặc gạch dưới.',
        ),
      );
    }
    return _repository.getArchives(username);
  }
}
