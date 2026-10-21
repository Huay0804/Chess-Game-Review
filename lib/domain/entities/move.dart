import 'package:equatable/equatable.dart';
import 'package:chess_game_review/domain/entities/player.dart';

enum PositionOutcome { ongoing, whiteWin, blackWin, draw }

class ChessPosition extends Equatable {
  static const standardFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  ChessPosition({
    required this.fen,
    required this.turn,
    required List<String> squares,
    required this.materialBalance,
    this.outcome = PositionOutcome.ongoing,
  }) : squares = List.unmodifiable(squares);
  final String fen;
  final ChessSide turn;

  /// Display order: a8..h8, a7..h7, ..., a1..h1; empty square = ''.
  final List<String> squares;

  /// Material advantage from White's perspective, in pawn units.
  final int materialBalance;
  final PositionOutcome outcome;
  bool get isTerminal => outcome != PositionOutcome.ongoing;
  @override
  List<Object?> get props => [fen, outcome];
}

class Move extends Equatable {
  const Move({
    required this.ply,
    required this.moveNumber,
    required this.san,
    required this.uci,
    required this.before,
    required this.after,
    this.clock,
  });
  final int ply;
  final int moveNumber;
  final String san;
  final String uci;
  final ChessPosition before;
  final ChessPosition after;
  final Duration? clock;
  ChessSide get side => before.turn;
  String get fenBefore => before.fen;
  String get fenAfter => after.fen;
  @override
  List<Object?> get props => [ply, san, uci, before, after, clock];
}

class ParsedGame {
  ParsedGame({required this.initial, required List<Move> moves})
    : moves = List.unmodifiable(moves);
  final ChessPosition initial;
  final List<Move> moves;
}
