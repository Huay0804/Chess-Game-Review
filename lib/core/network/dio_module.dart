import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  Dio get dio => Dio(
    BaseOptions(
      baseUrl: 'https://api.chess.com/pub',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': const String.fromEnvironment(
          'CHESS_USER_AGENT',
          defaultValue: 'ChessGameReview/1.0 (educational desktop application)',
        ),
        'Accept': 'application/json',
      },
    ),
  );
}
