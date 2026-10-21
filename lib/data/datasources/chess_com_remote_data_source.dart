import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/data/models/archive_dto.dart';
import 'package:chess_game_review/data/models/game_dto.dart';

@lazySingleton
class ChessComRemoteDataSource {
  ChessComRemoteDataSource(this._dio);
  final Dio _dio;
  Future<void> _tail = Future.value();

  // Chess.com requests must be serial, even when UI requests are superseded.
  Future<Map<String, dynamic>> _get(String path) {
    final next = _tail.then((_) async {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? (throw const FormatException('Empty response'));
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<List<ArchiveDto>> getArchives(String username) async {
    final json = await _get(
      '/player/${Uri.encodeComponent(username)}/games/archives',
    );
    return (json['archives'] as List)
        .map((e) => ArchiveDto.fromUrl(e as String))
        .toList();
  }

  Future<List<GameDto>> getMonthlyGames(
    String username,
    int year,
    int month,
  ) async {
    final path = '$year/${month.toString().padLeft(2, '0')}';
    final json = await _get(
      '/player/${Uri.encodeComponent(username)}/games/$path',
    );
    return (json['games'] as List)
        .map((e) => GameDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
