import 'dart:async';
import 'dart:ui' as ui;

import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/injection.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/pages/game_list_page.dart';
import 'package:chess_game_review/presentation/pages/review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GameListBloc _list;
  late final ReviewBloc _review;
  late final AppLifecycleListener _lifecycle;
  Future<void>? _shutdownFuture;

  @override
  void initState() {
    super.initState();
    _list = getIt<GameListBloc>();
    _review = getIt<ReviewBloc>();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _shutdown();
        return ui.AppExitResponse.exit;
      },
      onDetach: () => unawaited(_shutdown()),
    );
  }

  Future<void> _shutdown() => _shutdownFuture ??= _closeDependencies();

  Future<void> _closeDependencies() async {
    await _review.close();
    await _list.close();
    await getIt.reset();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _list),
      BlocProvider.value(value: _review),
    ],
    child: MaterialApp(
      title: 'Chess Game Review',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => GameListPage(
          onReview: (game) => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ReviewPage(game: game)),
          ),
        ),
      ),
    ),
  );
}
