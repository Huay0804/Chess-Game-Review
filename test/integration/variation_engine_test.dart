import 'dart:io';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/injection.dart';
import 'package:chess_game_review/presentation/bloc/variation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/variation_fixture.dart';

void main() {
  test(
    'real Stockfish analyzes an interactive branch and remains usable after cancellation',
    () async {
      await configureDependencies();
      final cubit = getIt<VariationCubit>()..load(variationFixture());
      addTearDown(() async {
        await cubit.close();
        await getIt<EvaluationEngine>().dispose();
        await getIt.reset();
      });
      Future<void> finish(String uci) async {
        await cubit.stream
            .firstWhere(
              (s) =>
                  s.move?.uci == uci &&
                  !s.busy &&
                  (s.analysis != null || s.error != null),
            )
            .timeout(const Duration(seconds: 90));
        expect(cubit.state.error, isNull);
        expect(cubit.state.analysis!.after.depth, greaterThanOrEqualTo(12));
      }

      cubit.play('d2d4');
      final first = finish('d2d4');
      await first;
      expect(cubit.state.analysis!.quality, MoveQuality.book);
      cubit.play('g8f6');
      cubit.play('c2c4');
      await finish('c2c4');
      expect(cubit.state.analysis!.move.uci, 'c2c4');
      cubit.returnToGame();
      expect(cubit.state.isBranch, false);
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip:
        !Platform.isWindows ||
            !File('engine/stockfish/stockfish.exe').existsSync()
        ? 'Requires the local Windows Stockfish executable.'
        : false,
  );
}
