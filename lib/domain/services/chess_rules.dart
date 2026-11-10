import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';

abstract interface class ChessRules {
  /// Throws [AppException] when the PGN cannot be parsed.
  ParsedGame parsePgn(String pgn);
  String? sanForUci(String fen, String uci);

  /// Standard UCI moves, including the four promotion choices.
  List<String> legalMoves(String fen);

  /// Validates and plays one move without changing the original game.
  Move playMove(String fen, String uci, {required int ply});
}
