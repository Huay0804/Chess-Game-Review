import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/bloc/variation_cubit.dart';
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
  late final VariationCubit _exploration;
  int _depth = ReviewConfig.defaultDepth;
  bool _flipped = false;
  ReviewView _view = ReviewView.overview;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ReviewBloc>();
    _exploration = context.read<VariationCubit>();
    _start();
    final state = _bloc.state;
    if (state is ReviewLoaded) _exploration.load(state.review);
  }

  void _start() {
    _view = ReviewView.overview;
    _hasStarted = false;
    _exploration.clear();
    _bloc.add(StartReview(widget.game, depth: _depth));
  }

  @override
  void dispose() {
    if (!_bloc.isClosed) _bloc.add(CancelReview());
    if (!_exploration.isClosed) _exploration.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Game review'),
      actions: [
        PopupMenuButton<int>(
          tooltip: 'Cài đặt phân tích',
          icon: const Icon(Icons.tune),
          initialValue: _depth,
          onSelected: (depth) {
            setState(() => _depth = depth);
            _start();
          },
          itemBuilder: (_) => [
            const PopupMenuItem<int>(
              enabled: false,
              child: Text(
                'Độ sâu phân tích\nĐộ sâu cao hơn cần nhiều thời gian hơn.',
              ),
            ),
            const PopupMenuDivider(),
            for (
              var depth = ReviewConfig.minDepth;
              depth <= ReviewConfig.maxDepth;
              depth++
            )
              CheckedPopupMenuItem(
                value: depth,
                checked: depth == _depth,
                child: Text('Độ sâu $depth'),
              ),
          ],
        ),
      ],
    ),
    body: BlocConsumer<ReviewBloc, ReviewState>(
      listener: (_, state) {
        if (state is ReviewLoaded) _exploration.load(state.review);
      },
      builder: (context, state) {
        if (state is ReviewLoaded) {
          return BlocBuilder<VariationCubit, VariationState>(
            builder: (context, variation) => ReviewContent(
              view: _view,
              hasStarted: _hasStarted,
              onViewChanged: (view) => setState(() {
                _view = view;
                if (view == ReviewView.moves) _hasStarted = true;
              }),
              review: state.review,
              selectedPly: variation.basePly,
              exploration: _exploration,
              flipped: _flipped,
              onSelect: _exploration.selectOriginal,
              onFlip: () => setState(() => _flipped = !_flipped),
            ),
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
