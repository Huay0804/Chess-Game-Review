import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:injectable/injectable.dart';

/// Synchronous rules access: moving a piece never waits for the engine.
@injectable
class ExploreMoves {
  const ExploreMoves(this._rules);
  final ChessRules _rules;

  List<String> legalMoves(ChessPosition position) =>
      _rules.legalMoves(position.fen);

  Move call(ChessPosition position, String uci, {required int ply}) =>
      _rules.playMove(position.fen, uci, ply: ply);
}
