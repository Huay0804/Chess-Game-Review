import 'package:dartchess/dartchess.dart' as dc;
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';

@LazySingleton(as: ChessRules)
class DartchessRules implements ChessRules {
  String _standardUci(dc.Position position, dc.Move move) {
    final san = position.makeSan(move).$2;
    final rank = position.turn == dc.Side.white ? '1' : '8';
    return san.startsWith('O-O-O')
        ? 'e${rank}c$rank'
        : san.startsWith('O-O')
        ? 'e${rank}g$rank'
        : move.uci;
  }

  @override
  List<String> legalMoves(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      if (position.isGameOver) return const [];
      return [
        for (final entry in position.legalMoves.entries)
          for (final to in entry.value.squares)
            if (position.board.roleAt(entry.key) == dc.Role.pawn &&
                (to.name.endsWith('8') || to.name.endsWith('1')))
              for (final role in [
                dc.Role.queen,
                dc.Role.rook,
                dc.Role.bishop,
                dc.Role.knight,
              ])
                dc.NormalMove(from: entry.key, to: to, promotion: role).uci
            else
              _standardUci(position, dc.NormalMove(from: entry.key, to: to)),
      ];
    } catch (_) {
      throw const ParseException(
        'Chưa đọc được vị trí này. Bạn hãy chọn lại một nước trong ván gốc.',
      );
    }
  }

  @override
  Move playMove(String fen, String uci, {required int ply}) {
    if (!legalMoves(fen).contains(uci)) {
      throw const ParseException(
        'Nước đi chưa hợp lệ. Bạn hãy chọn một ô được gợi ý.',
      );
    }
    final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
    final move = dc.Move.parse(uci)!;
    return Move(
      ply: ply,
      moveNumber: position.fullmoves,
      san: position.makeSan(move).$2,
      uci: uci,
      before: _snapshot(position),
      after: _snapshot(position.play(move)),
    );
  }

  @override
  ParsedGame parsePgn(String pgn) {
    try {
      if (pgn.trim().isEmpty) {
        throw const ParseException(
          'Ván cờ này chưa có dữ liệu nước đi. Bạn hãy chọn ván khác.',
        );
      }
      final game = dc.PgnGame.parsePgn(pgn);
      if (game.headers['Variant'] != null &&
          game.headers['Variant'] != 'Standard') {
        throw const ParseException(
          'Hiện chỉ phân tích cờ vua tiêu chuẩn. '
          'Bạn hãy chọn một ván cờ tiêu chuẩn.',
        );
      }
      var position = dc.PgnGame.startingPosition(game.headers);
      if (position.rule != dc.Rule.chess) {
        throw const ParseException(
          'Hiện chỉ phân tích cờ vua tiêu chuẩn. '
          'Bạn hãy chọn một ván cờ tiêu chuẩn.',
        );
      }
      final initial = _snapshot(position);
      final nodes = game.moves.mainline().toList();
      if (nodes.isEmpty) {
        throw const ParseException(
          'Ván cờ này chưa có nước đi để phân tích. Bạn hãy chọn ván khác.',
        );
      }
      final moves = <Move>[];
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final move = position.parseSan(node.san);
        if (move == null || !position.isLegal(move)) {
          throw ParseException(
            'Không đọc được nước đi thứ ${i + 1}. Bạn hãy thử tải lại ván cờ.',
          );
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
      return ParsedGame(initial: initial, moves: moves);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ParseException(
        'Chưa đọc được ván cờ này. Bạn hãy thử tải lại hoặc chọn ván khác.',
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
