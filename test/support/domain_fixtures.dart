import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';

final testGame = Game(
  url: 'test:game',
  white: const Player(username: 'White', rating: 1500, result: 'win'),
  black: const Player(username: 'Black', rating: 1500, result: 'resigned'),
  timeClass: 'rapid',
  timeControl: '600',
  endTime: DateTime.utc(2025),
  rated: true,
  pgn: 'test-pgn',
  finalFen: '',
);

ChessPosition testPosition(
  String fen,
  ChessSide side, {
  PositionOutcome outcome = PositionOutcome.ongoing,
}) => ChessPosition(
  fen: fen,
  turn: side,
  squares: List.filled(64, ''),
  materialBalance: 0,
  outcome: outcome,
);

Move testMove(
  ChessPosition before,
  ChessPosition after, {
  int ply = 1,
  String uci = 'e2e4',
}) => Move(
  ply: ply,
  moveNumber: (ply + 1) ~/ 2,
  san: 'e4',
  uci: uci,
  before: before,
  after: after,
);

MoveAnalysis testAnalysis(ChessSide side, double loss) => MoveAnalysis(
  move: testMove(
    testPosition('before', side),
    testPosition('after', side.opposite),
  ),
  before: const PositionEval(cpWhite: 0),
  after: const PositionEval(cpWhite: 0),
  loss: loss,
  quality: loss > .2 ? MoveQuality.blunder : MoveQuality.best,
  accuracy: 0,
);
