import 'package:chess_game_review/data/repositories/game_repository_impl.dart';
import 'package:chess_game_review/data/services/stockfish_evaluation_engine.dart';
import 'package:chess_game_review/domain/repositories/game_repository.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/injection.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';

void main() {
  tearDown(() => getIt.reset());
  test(
    'DI builds real services and factory Blocs with a shared engine',
    () async {
      await configureDependencies();
      expect(getIt<GameRepository>(), isA<GameRepositoryImpl>());
      expect(getIt<EvaluationEngine>(), isA<StockfishEvaluationEngine>());
      expect(getIt<EvaluationEngine>(), same(getIt<EvaluationEngine>()));
      final list = getIt<GameListBloc>();
      final first = getIt<ReviewBloc>();
      final second = getIt<ReviewBloc>();
      expect(first, isNot(same(second)));
      await list.close();
      await first.close();
      await second.close();
    },
  );
  test(
    'DI resolves one Dio instance with an identifiable User-Agent',
    () async {
      await configureDependencies();
      expect(getIt<Dio>(), same(getIt<Dio>()));
      expect(
        getIt<Dio>().options.headers['User-Agent'],
        contains('ChessGameReview'),
      );
      expect(getIt<Dio>().options.baseUrl, 'https://api.chess.com/pub');
    },
  );
  test('Failures preserve type and value equality', () {
    expect(const NotFoundException(), const NotFoundException());
    expect(const NotFoundException(), isNot(const ServerException()));
  });
  testWidgets('Flutter application compiles and renders with the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('Chess Game Review')),
      ),
    );
    expect(find.text('Chess Game Review'), findsOneWidget);
  });
}
