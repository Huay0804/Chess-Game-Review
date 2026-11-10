import 'dart:math' as math;
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/bloc/variation_cubit.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/eval_bar.dart';
import 'package:chess_game_review/presentation/widgets/eval_chart.dart';
import 'package:chess_game_review/presentation/widgets/move_list.dart';
import 'package:chess_game_review/presentation/widgets/help_button.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ReviewView { overview, moves }

class ReviewContent extends StatefulWidget {
  const ReviewContent({
    super.key,
    required this.review,
    required this.selectedPly,
    required this.flipped,
    required this.onSelect,
    required this.onFlip,
    required this.view,
    required this.onViewChanged,
    this.hasStarted = false,
    this.exploration,
  });
  final GameReview review;
  final int selectedPly;
  final bool flipped, hasStarted;
  final ValueChanged<int> onSelect;
  final VoidCallback onFlip;
  final ReviewView view;
  final ValueChanged<ReviewView> onViewChanged;
  final VariationCubit? exploration;
  @override
  State<ReviewContent> createState() => _ReviewContentState();
}

class _ReviewContentState extends State<ReviewContent> {
  // Reparent the same board when the window crosses the responsive breakpoint.
  final _boardKey = GlobalKey();
  int get _index =>
      widget.exploration?.state.navigationIndex ?? widget.selectedPly;
  int get _length => widget.exploration?.state.isBranch == true
      ? widget.exploration!.state.moves.length
      : widget.review.moves.length;
  void _navigate(int index) {
    widget.onViewChanged(ReviewView.moves);
    if (widget.exploration != null) {
      widget.exploration!.navigate(index);
    } else {
      widget.onSelect(index);
    }
  }

  void _selectOriginal(int ply) {
    widget.onViewChanged(ReviewView.moves);
    widget.onSelect(ply);
  }

  void _start() {
    if (widget.hasStarted) {
      widget.onViewChanged(ReviewView.moves);
    } else {
      _navigate(_length == 0 ? 0 : 1);
    }
  }

  Widget _sidebar(bool bounded) {
    final state = widget.exploration?.state;
    final current = state != null
        ? state.analysis
        : widget.selectedPly == 0
        ? null
        : widget.review.moves[widget.selectedPly - 1];
    final evaluation = state != null
        ? state.evaluation
        : current?.after ?? widget.review.initialEval;
    Widget graph({bool compact = false}) => ReviewGraph(
      review: widget.review,
      selectedPly: widget.selectedPly,
      onSelect: _selectOriginal,
      compact: compact,
    );
    final start = Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('start-review'),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            widget.hasStarted ? 'Tiếp tục xem lại' : 'Bắt đầu xem lại',
          ),
        ),
      ),
    );
    if (widget.view == ReviewView.overview) {
      final overview = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          graph(),
          ReviewSummary(review: widget.review),
          start,
        ],
      );
      return bounded
          ? Padding(
              // Exclude the board's bottom toolbar when matching its center.
              padding: const EdgeInsets.only(bottom: 48),
              child: Center(
                child: SingleChildScrollView(
                  key: const Key('overview-scroll'),
                  child: overview,
                ),
              ),
            )
          : overview;
    }
    final feedback = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state?.isBranch == true)
          ReviewVariationPanel(exploration: widget.exploration!),
        if (state?.busy == true)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Đang phân tích…')),
              ],
            ),
          )
        else if (state?.error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(state!.error!.message),
                  TextButton(
                    onPressed: widget.exploration!.retry,
                    child: const Text('Thử phân tích lại'),
                  ),
                ],
              ),
            ),
          )
        else if (current != null)
          MoveInsight(analysis: current)
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Vị trí ban đầu'),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => widget.onViewChanged(ReviewView.overview),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Tổng kết'),
            ),
          ),
          if (bounded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * .30),
              child: SingleChildScrollView(
                key: const Key('move-feedback-scroll'),
                child: feedback,
              ),
            )
          else
            feedback,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              state?.isBranch == true ? 'Ván gốc' : 'Từng nước đi',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (bounded)
            Expanded(
              child: MoveList(
                moves: widget.review.moves,
                selectedPly: widget.selectedPly,
                onSelect: _selectOriginal,
                fillHeight: true,
              ),
            )
          else
            MoveList(
              moves: widget.review.moves,
              selectedPly: widget.selectedPly,
              onSelect: _selectOriginal,
            ),
          graph(compact: true),
          ReviewBoardControls(
            evaluation: evaluation,
            selectedPly: _index,
            moveCount: _length,
            onSelect: _navigate,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _navigate((_index - 1).clamp(0, _length)),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _navigate((_index + 1).clamp(0, _length)),
      const SingleActivator(LogicalKeyboardKey.home): () => _navigate(0),
      const SingleActivator(LogicalKeyboardKey.end): () => _navigate(_length),
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          widget.exploration?.returnToGame(),
    },
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final wide = box.maxWidth >= 890 && box.maxHeight >= 560 * scale;
          final board = ReviewBoardPanel(
            boardKey: _boardKey,
            bounded: wide,
            review: widget.review,
            selectedPly: widget.selectedPly,
            flipped: widget.flipped,
            onFlip: widget.onFlip,
            exploration: widget.exploration,
            onMove: widget.exploration == null
                ? null
                : (uci) {
                    widget.onViewChanged(ReviewView.moves);
                    widget.exploration!.play(uci);
                  },
          );
          final sidebar = TweenAnimationBuilder<double>(
            key: ValueKey(widget.view),
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: _sidebar(wide),
          );
          if (wide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: board),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: sidebar),
                    ],
                  ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            key: const Key('review-page-scroll'),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [board, const SizedBox(height: 16), sidebar],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class ReviewStatusPanel extends StatelessWidget {
  const ReviewStatusPanel({
    super.key,
    required this.state,
    required this.onCancel,
    required this.onRetry,
  });

  final ReviewState state;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final progress = switch (state) {
      ReviewInProgress(:final progress) => progress,
      _ => null,
    };
    final failureMessage = switch (state) {
      ReviewFailed(:final failure) => failure.message,
      _ => null,
    };
    final busy = state is ReviewLoading || state is ReviewInProgress;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                busy ? Icons.manage_search : Icons.info_outline,
                size: 56,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 24),
              Text(
                state is ReviewFailed
                    ? 'Chưa thể phân tích'
                    : busy
                    ? 'Đang phân tích…'
                    : 'Phân tích đã dừng',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (busy) ...[
                LinearProgressIndicator(
                  value: progress == null || progress.total == 0
                      ? null
                      : progress.completed / progress.total,
                ),
                const SizedBox(height: 14),
                Text(
                  progress == null
                      ? 'Đang chuẩn bị…'
                      : '${progress.completed} / ${progress.total} nước${progress.currentSan == null ? '' : ' • ${progress.currentSan}'}',
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Hủy phân tích'),
                ),
              ] else ...[
                if (failureMessage != null)
                  Text(failureMessage, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Phân tích lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewBoardPanel extends StatelessWidget {
  const ReviewBoardPanel({
    super.key,
    required this.review,
    required this.selectedPly,
    required this.flipped,
    required this.onFlip,
    required this.boardKey,
    required this.bounded,
    this.onMove,
    this.exploration,
  });
  final GameReview review;
  final int selectedPly;
  final bool flipped, bounded;
  final VoidCallback onFlip;
  final Key boardKey;
  final ValueChanged<String>? onMove;
  final VariationCubit? exploration;

  @override
  Widget build(BuildContext context) {
    final state = exploration?.state;
    final current = state != null
        ? state.analysis
        : selectedPly == 0
        ? null
        : review.moves[selectedPly - 1];
    final position = state?.position ?? current?.move.after ?? review.initial;
    final evaluation = state != null
        ? state.evaluation
        : current?.after ?? review.initialEval;
    Widget player(Player player, bool white) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            white ? Icons.circle_outlined : Icons.circle,
            size: 16,
            color: AppTheme.muted,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text('${player.username}  (${player.rating})')),
        ],
      ),
    );
    final board = LayoutBuilder(
      builder: (context, box) {
        final size = math.max(1.0, math.min(box.maxWidth - 38, box.maxHeight));
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: size + 38,
            height: size,
            child: Row(
              children: [
                EvalBar(evaluation: evaluation, height: size, flipped: flipped),
                const SizedBox(width: 10),
                Expanded(
                  child: ChessBoard(
                    key: boardKey,
                    position: position,
                    flipped: flipped,
                    lastUci: state?.move?.uci ?? current?.move.uci,
                    move: state?.move ?? current?.move,
                    quality: current?.quality,
                    legalMoves: state?.legalMoves ?? const [],
                    onMove: onMove,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return Column(
      mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        player(flipped ? review.game.white : review.game.black, flipped),
        if (bounded) Expanded(child: board) else board,
        player(flipped ? review.game.black : review.game.white, !flipped),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            IconButton(
              tooltip: 'Đảo bàn cờ',
              onPressed: onFlip,
              icon: const Icon(Icons.flip_camera_android_outlined),
            ),
            if (exploration != null)
              const HelpButton(
                label: 'Hướng dẫn bàn cờ',
                message:
                    'Kéo quân để thử nước đi. Các chấm và vòng tròn chỉ ô hợp lệ. '
                    'Dùng phím ← → để xem nước trước hoặc tiếp. '
                    'Chọn “Về ván gốc” hoặc nhấn Esc để thoát nhánh thử.',
              ),
          ],
        ),
      ],
    );
  }
}

class ReviewVariationPanel extends StatelessWidget {
  const ReviewVariationPanel({super.key, required this.exploration});
  final VariationCubit exploration;
  @override
  Widget build(BuildContext context) {
    final state = exploration.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Nhánh phân tích',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: exploration.returnToGame,
                  icon: const Icon(Icons.undo),
                  label: const Text('Về ván gốc'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Điểm rẽ'),
                  selected: state.cursor == 0,
                  onSelected: (_) => exploration.navigate(0),
                ),
                for (var i = 0; i < state.moves.length; i++)
                  ChoiceChip(
                    label: Text(
                      '${state.moves[i].moveNumber}${state.moves[i].side == ChessSide.white ? '.' : '...'} ${state.moves[i].san}',
                    ),
                    selected: state.cursor == i + 1,
                    onSelected: (_) => exploration.navigate(i + 1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewGraph extends StatelessWidget {
  const ReviewGraph({
    super.key,
    required this.review,
    required this.selectedPly,
    required this.onSelect,
    this.compact = false,
  });
  final GameReview review;
  final int selectedPly;
  final ValueChanged<int> onSelect;
  final bool compact;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Đánh giá — ván gốc',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
          EvalChart(
            evaluations: review.timeline,
            selectedPly: selectedPly,
            onSelect: onSelect,
            height: compact ? 100 : 150,
          ),
        ],
      ),
    ),
  );
}

class ReviewBoardControls extends StatelessWidget {
  const ReviewBoardControls({
    super.key,
    required this.evaluation,
    required this.selectedPly,
    required this.moveCount,
    required this.onSelect,
  });

  final PositionEval? evaluation;
  final int selectedPly;
  final int moveCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            evaluation == null ? '—' : evaluationLabel(evaluation!),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$selectedPly / $moveCount',
            style: const TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          IconButton(
            tooltip: 'Về đầu',
            onPressed: selectedPly > 0 ? () => onSelect(0) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Nước trước',
            onPressed: selectedPly > 0 ? () => onSelect(selectedPly - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Nước tiếp',
            onPressed: selectedPly < moveCount
                ? () => onSelect(selectedPly + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Về cuối',
            onPressed: selectedPly < moveCount
                ? () => onSelect(moveCount)
                : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    ],
  );
}

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({super.key, required this.review});
  final GameReview review;
  @override
  Widget build(BuildContext context) {
    final white = review.countsFor(ChessSide.white),
        black = review.countsFor(ChessSide.black);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng kết ván đấu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, box) {
                final whiteAccuracy = _Accuracy(
                  name: review.game.white.username,
                  value: review.accuracy.white,
                  label: 'TRẮNG',
                );
                final blackAccuracy = _Accuracy(
                  name: review.game.black.username,
                  value: review.accuracy.black,
                  label: 'ĐEN',
                );
                // Each score needs room for "100.0", including large text.
                if (box.maxWidth <
                    11 * MediaQuery.textScalerOf(context).scale(32)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      whiteAccuracy,
                      const Divider(height: 24),
                      blackAccuracy,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: whiteAccuracy),
                    Container(width: 1, height: 60, color: Colors.white12),
                    Expanded(child: blackAccuracy),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            for (final quality in MoveQuality.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${white[quality]}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: quality.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              quality.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: quality.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${black[quality]}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Accuracy extends StatelessWidget {
  const _Accuracy({
    required this.name,
    required this.value,
    required this.label,
  });
  final String name, label;
  final double? value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value?.toStringAsFixed(1) ?? '—',
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}

class MoveInsight extends StatelessWidget {
  const MoveInsight({super.key, required this.analysis});

  final MoveAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final item = analysis;
    if (item == null) return const SizedBox.shrink();
    final bestMove = item.bestMoveSan ?? item.before.bestMove;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${item.move.moveNumber}${item.move.side == ChessSide.white ? '.' : '...'} ${item.move.san}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                QualityChip(item.quality),
                if (item.quality.isHeuristic)
                  const HelpButton(
                    label: 'Về nhãn chất lượng',
                    message: 'Phân loại mang tính tham khảo.',
                  ),
                Text(
                  clockLabel(item.move.clock),
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
            if (item.opening != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Khai cuộc: ${item.opening}'),
              ),
            if (item.quality.needsSuggestion)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  bestMove == null
                      ? 'Chưa có gợi ý'
                      : 'Nước tốt nhất: $bestMove',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ExpansionTile(
              key: ValueKey(
                'move-details-${item.move.ply}-${item.move.after.fen}',
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Chi tiết'),
              children: [
                Text(
                  'Giảm cơ hội thắng: ${(item.loss * 100).toStringAsFixed(1)} điểm phần trăm',
                ),
                Text(
                  'Độ chính xác nước đi: ${item.accuracy.toStringAsFixed(1)}',
                ),
                if (item.quality.needsSuggestion && item.before.pv.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Biến phân tích (UCI): ${item.before.pv.take(8).join(' ')}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
