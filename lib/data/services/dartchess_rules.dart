import 'package:dartchess/dartchess.dart' as dc;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';

@LazySingleton(as: ChessRules)
class DartchessRules implements ChessRules {
  @override
  Either<Failure, ParsedGame> parsePgn(String pgn) {
    try {
      if (pgn.trim().isEmpty) return const Left(ParseFailure('PGN trống.'));
      final game = dc.PgnGame.parsePgn(pgn);
      if (game.headers['Variant'] != null &&
          game.headers['Variant'] != 'Standard') {
        return const Left(ParseFailure('Hiện chỉ hỗ trợ cờ vua tiêu chuẩn.'));
      }
      var position = dc.PgnGame.startingPosition(game.headers);
      if (position.rule != dc.Rule.chess) {
        return const Left(ParseFailure('Biến thể chưa hỗ trợ.'));
      }
      final initial = _snapshot(position);
      final nodes = game.moves.mainline().toList();
      if (nodes.isEmpty) {
        return const Left(ParseFailure('PGN không có nước đi.'));
      }
      final moves = <Move>[];
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final move = position.parseSan(node.san);
        if (move == null || !position.isLegal(move)) {
          return Left(ParseFailure('Nước ${i + 1} không hợp lệ: ${node.san}'));
        }
        final before = _snapshot(position);
        final san = position.makeSan(move).$2;
        final rank = before.turn == ChessSide.white ? '1' : '8';
        // dartchess represents castling internally as king-to-rook.
        final uci = san.startsWith('O-O-O')
            ? 'e${rank}c$rank'
            : san.startsWith('O-O')
            ? 'e${rank}g$rank'
            : move.uci;
        final number = position.fullmoves;
        position = position.play(move);
        moves.add(
          Move(
            ply: i + 1,
            moveNumber: number,
            san: san,
            uci: uci,
            before: before,
            after: _snapshot(
              position,
              agreedDraw:
                  i == nodes.length - 1 && game.headers['Result'] == '1/2-1/2',
            ),
            clock: _clock(node.comments ?? []),
          ),
        );
      }
      return Right(ParsedGame(initial: initial, moves: moves));
    } catch (_) {
      return const Left(
        ParseFailure('Không đọc được PGN hoặc FEN của ván cờ.'),
      );
    }
  }

  Duration? _clock(List<String> comments) {
    final match = RegExp(
      r'\[%clk\s+(\d+):(\d{2}):(\d{2}(?:\.\d+)?)\]',
    ).firstMatch(comments.join(' '));
    if (match == null) return null;
    final seconds =
        int.parse(match[1]!) * 3600 +
        int.parse(match[2]!) * 60 +
        double.parse(match[3]!);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  ChessPosition _snapshot(dc.Position position, {bool agreedDraw = false}) {
    final squares = <String>[];
    var material = 0;
    for (final character in position.fen.split(' ').first.split('')) {
      if (character == '/') continue;
      final empty = int.tryParse(character);
      if (empty != null) {
        squares.addAll(List.filled(empty, ''));
      } else {
        squares.add(character);
        material +=
            (ReviewConfig.materialValues[character.toLowerCase()] ?? 0) *
            (character == character.toUpperCase() ? 1 : -1);
      }
    }
    final result = position.outcome;
    final outcome = result?.winner == dc.Side.white
        ? PositionOutcome.whiteWin
        : result?.winner == dc.Side.black
        ? PositionOutcome.blackWin
        : result != null || agreedDraw
        ? PositionOutcome.draw
        : PositionOutcome.ongoing;
    return ChessPosition(
      fen: position.fen,
      turn: position.turn == dc.Side.white ? ChessSide.white : ChessSide.black,
      squares: squares,
      materialBalance: material,
      outcome: outcome,
    );
  }

  @override
  String? sanForUci(String fen, String uci) {
    try {
      if (uci.length < 4) return null;
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final move = dc.Move.parse(uci);
      return move == null || !position.isLegal(move)
          ? null
          : position.makeSan(move).$2;
    } catch (_) {
      return null;
    }
  }
}
