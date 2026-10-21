import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('centipawns and mate scores are normalized to White', () {
    expect(
      PositionEval.normalizedCp(
        score: 130,
        isMate: false,
        turn: ChessSide.black,
      ),
      -130,
    );
    expect(
      PositionEval.normalizedCp(score: 3, isMate: true, turn: ChessSide.white),
      ReviewConfig.mateCp - 3,
    );
    expect(
      PositionEval.normalizedCp(score: -2, isMate: true, turn: ChessSide.black),
      ReviewConfig.mateCp - 2,
    );
    expect(
      PositionEval.normalizedCp(score: 0, isMate: true, turn: ChessSide.black),
      ReviewConfig.mateCp,
    );
    expect(
      PositionEval.normalizedCp(score: 0, isMate: true, turn: ChessSide.white),
      -ReviewConfig.mateCp,
    );
  });
  test('cancellation is idempotent and listeners can be detached', () {
    final token = CancellationToken();
    var calls = 0;
    token.listen(() => calls++);
    final detach = token.listen(() => calls += 100);
    detach();
    token.cancel();
    token.cancel();
    expect(calls, 1);
    token.listen(() => calls++);
    expect(calls, 2);
  });
}
