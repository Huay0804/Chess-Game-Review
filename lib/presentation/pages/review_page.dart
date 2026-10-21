import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/widgets/review_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.game});

  final Game game;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final ReviewBloc _bloc;
  int _depth = ReviewConfig.defaultDepth;
  int _selectedPly = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ReviewBloc>();
    _start();
  }

  void _start() => _bloc.add(StartReview(widget.game, depth: _depth));

  void _select(int ply) => setState(() => _selectedPly = ply);

  @override
  void dispose() {
    if (!_bloc.isClosed) _bloc.add(CancelReview());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Game review'),
      actions: [
        PopupMenuButton<int>(
          tooltip: 'Độ sâu phân tích',
          initialValue: _depth,
          onSelected: (depth) {
            setState(() => _depth = depth);
            _start();
          },
          itemBuilder: (_) => [
            for (
              var depth = ReviewConfig.minDepth;
              depth <= ReviewConfig.maxDepth;
              depth++
            )
              PopupMenuItem(value: depth, child: Text('Depth $depth')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text(
                'DEPTH $_depth ▾',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    ),
    body: BlocConsumer<ReviewBloc, ReviewState>(
      listener: (_, state) {
        if (state is ReviewLoaded) setState(() => _selectedPly = 0);
      },
      builder: (context, state) {
        if (state is ReviewLoaded) {
          return ReviewContent(
            review: state.review,
            selectedPly: _selectedPly.clamp(0, state.review.moves.length),
            flipped: _flipped,
            onSelect: _select,
            onFlip: () => setState(() => _flipped = !_flipped),
          );
        }
        return ReviewStatusPanel(
          state: state,
          onCancel: () => _bloc.add(CancelReview()),
          onRetry: _start,
        );
      },
    ),
  );
}
