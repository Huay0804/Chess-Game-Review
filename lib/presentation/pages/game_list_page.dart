import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:chess_game_review/presentation/widgets/game_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GameListPage extends StatefulWidget {
  const GameListPage({super.key, this.onReview});

  final ValueChanged<Game>? onReview;

  @override
  State<GameListPage> createState() => _GameListPageState();
}

class _GameListPageState extends State<GameListPage> {
  final _username = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _search() {
    if (_form.currentState!.validate()) {
      context.read<GameListBloc>().add(SearchPlayer(_username.text));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('♞  CHESS / REVIEW'),
      actions: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Text(
              'STOCKFISH • LOCAL',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    ),
    body: GameListBody(
      usernameController: _username,
      formKey: _form,
      onSearch: _search,
      onReview: widget.onReview,
    ),
  );
}
