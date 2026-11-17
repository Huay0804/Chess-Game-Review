import 'dart:convert';
import 'dart:io';
import 'package:chess_game_review/data/models/game_dto.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/chess_rules.dart';
import 'package:chess_game_review/domain/usecases/analyze_move.dart';
import 'package:chess_game_review/domain/usecases/review_game.dart';
import 'package:chess_game_review/injection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final unavailable =
      !Platform.isWindows ||
      !File('engine/stockfish/stockfish.exe').existsSync();
  test(
    'recorded and interactive review agree on a real saved game',
    () async {
      await configureDependencies();
      final token = CancellationToken();
      addTearDown(() async {
        token.cancel();
        await getIt.reset();
      });
      final json =
          jsonDecode(
                File('test/fixtures/chess_com_month.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final game = GameDto.fromChessCom(
        (json['games'] as List).first as Map<String, dynamic>,
      ).toEntity();
      final events = await getIt<ReviewGame>()(
        ReviewGameParams(game: game, cancellation: token, depth: 12),
      ).toList();
      final review = events.last.review!;
      final line = <String>[];
      for (var i = 0; i < review.moves.length; i++) {
        final recorded = review.moves[i];
        line.add(recorded.move.uci);
        final interactive = await getIt<AnalyzeMove>()(
          recorded.move,
          depth: 12,
          cancellation: token,
          openingLine: line,
          opponentLoss: i == 0 ? 0 : review.moves[i - 1].loss,
        );
        expect(interactive.quality, recorded.quality, reason: 'ply ${i + 1}');
        expect(interactive.loss, recorded.loss);
        expect(interactive.accuracy, recorded.accuracy);
        if (recorded.quality == MoveQuality.best) {
          expect(recorded.move.uci, recorded.before.bestMove);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip: unavailable
        ? 'Requires the local Windows Stockfish executable.'
        : false,
  );

  test(
    'real Stockfish does not label an ordinary knight exchange Brilliant',
    () async {
      await configureDependencies();
      final token = CancellationToken();
      addTearDown(() async {
        token.cancel();
        await getIt.reset();
      });
      final parsed = getIt<ChessRules>().parsePgn(
        '1. e4 e5 2. Nf3 Nc6 3. Nc3 Nf6 4. d4 exd4 5. Nxd4 Nxd4 6. Qxd4 *',
      );
      final move = parsed.moves[8];
      expect(move.uci, 'f3d4');
      final analysis = await getIt<AnalyzeMove>()(
        move,
        depth: 12,
        cancellation: token,
      );
      expect(analysis.quality, isNot(MoveQuality.brilliant));
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: unavailable
        ? 'Requires the local Windows Stockfish executable.'
        : false,
  );
}
