import 'package:fpdart/fpdart.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/move.dart';

abstract interface class ChessRules {
  Either<Failure, ParsedGame> parsePgn(String pgn);
  String? sanForUci(String fen, String uci);
}
