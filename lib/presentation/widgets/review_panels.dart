import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/presentation/bloc/review_bloc.dart';
import 'package:chess_game_review/presentation/widgets/chess_board.dart';
import 'package:chess_game_review/presentation/widgets/eval_bar.dart';
import 'package:chess_game_review/presentation/widgets/eval_chart.dart';
import 'package:chess_game_review/presentation/widgets/move_list.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReviewContent extends StatelessWidget {
  const ReviewContent({
    super.key,
    required this.review,
    required this.selectedPly,
    required this.flipped,
    required this.onSelect,
    required this.onFlip,
  });

  final GameReview review;
  final int selectedPly;
  final bool flipped;
  final ValueChanged<int> onSelect;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          onSelect((selectedPly - 1).clamp(0, review.moves.length)),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          onSelect((selectedPly + 1).clamp(0, review.moves.length)),
      const SingleActivator(LogicalKeyboardKey.home): () => onSelect(0),
      const SingleActivator(LogicalKeyboardKey.end): () =>
          onSelect(review.moves.length),
    },
    child: Focus(
      autofocus: true,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 850
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: ReviewBoardPanel(
                              review: review,
                              selectedPly: selectedPly,
                              flipped: flipped,
                              onSelect: onSelect,
                              onFlip: onFlip,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: ReviewDetailsPanel(
                              review: review,
                              selectedPly: selectedPly,
                              onSelect: onSelect,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          ReviewBoardPanel(
                            review: review,
                            selectedPly: selectedPly,
                            flipped: flipped,
                            onSelect: onSelect,
                            onFlip: onFlip,
                          ),
                          const SizedBox(height: 16),
                          ReviewDetailsPanel(
                            review: review,
                            selectedPly: selectedPly,
                            onSelect: onSelect,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
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
        child: Padding(
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
                    ? 'Đang đọc vị trí…'
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
                      ? 'Chuẩn bị engine'
                      : '${progress.completed} / ${progress.total} nước${progress.currentSan == null ? '' : ' • ${progress.currentSan}'}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Depth cao hơn cần nhiều thời gian hơn.',
                  style: TextStyle(color: AppTheme.muted),
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
    required this.onSelect,
    required this.onFlip,
  });

  final GameReview review;
  final int selectedPly;
  final bool flipped;
  final ValueChanged<int> onSelect;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final current = selectedPly == 0 ? null : review.moves[selectedPly - 1];
    final position = current?.move.after ?? review.initial;
    final evaluation = current?.after ?? review.initialEval;
    final topPlayer = flipped ? review.game.white : review.game.black;
    final bottomPlayer = flipped ? review.game.black : review.game.white;

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
          Expanded(
            child: Text(
              '${player.username}  (${player.rating})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            player.result,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final boardSize = box.maxWidth - 38;
        return Column(
          children: [
            player(topPlayer, flipped),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EvalBar(
                  evaluation: evaluation,
                  height: boardSize,
                  flipped: flipped,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChessBoard(
                    key: const Key('review-board'),
                    position: position,
                    flipped: flipped,
                    lastUci: current?.move.uci,
                  ),
                ),
              ],
            ),
            player(bottomPlayer, !flipped),
            ReviewBoardControls(
              evaluation: evaluation,
              selectedPly: selectedPly,
              moveCount: review.moves.length,
              onFlip: onFlip,
              onSelect: onSelect,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIỄN BIẾN ĐÁNH GIÁ',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    EvalChart(
                      evaluations: review.timeline,
                      selectedPly: selectedPly,
                      onSelect: onSelect,
                    ),
                    const Text(
                      'Điểm phía Trắng • Bấm biểu đồ để xem nước đi • Trục giới hạn ±10 tốt',
                      style: TextStyle(color: AppTheme.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            MoveInsight(analysis: current),
          ],
        );
      },
    );
  }
}

class ReviewBoardControls extends StatelessWidget {
  const ReviewBoardControls({
    super.key,
    required this.evaluation,
    required this.selectedPly,
    required this.moveCount,
    required this.onFlip,
    required this.onSelect,
  });

  final PositionEval evaluation;
  final int selectedPly;
  final int moveCount;
  final VoidCallback onFlip;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(
            evaluationLabel(evaluation),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$selectedPly / $moveCount',
            style: const TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Đảo bàn cờ',
            onPressed: onFlip,
            icon: const Icon(Icons.flip_camera_android_outlined),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
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

class ReviewDetailsPanel extends StatelessWidget {
  const ReviewDetailsPanel({
    super.key,
    required this.review,
    required this.selectedPly,
    required this.onSelect,
  });

  final GameReview review;
  final int selectedPly;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ReviewSummary(review: review),
      const SizedBox(height: 12),
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Từng nước đi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            MoveList(
              moves: review.moves,
              selectedPly: selectedPly,
              onSelect: onSelect,
            ),
          ],
        ),
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
            Row(
              children: [
                Expanded(
                  child: _Accuracy(
                    name: review.game.white.username,
                    value: review.accuracy.white,
                    label: 'TRẮNG',
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.white12),
                Expanded(
                  child: _Accuracy(
                    name: review.game.black.username,
                    value: review.accuracy.black,
                    label: 'ĐEN',
                  ),
                ),
              ],
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
                          Text(
                            quality.label,
                            style: TextStyle(color: quality.color),
                          ),
                          if (quality.isHeuristic)
                            const Text(
                              ' *',
                              style: TextStyle(color: AppTheme.muted),
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
            const Text(
              'Accuracy là xấp xỉ. * Brilliant, Great, Miss là heuristic; cần xem lại biến engine để hiểu vị trí.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item == null)
              const Text(
                'Chọn một nước đi hoặc dùng phím ← → để bắt đầu xem lại.',
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${item.move.moveNumber}${item.move.side == ChessSide.white ? '.' : '...'} ${item.move.san}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  QualityChip(item.quality),
                  const Spacer(),
                  Text(
                    clockLabel(item.move.clock),
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Mất ${(item.loss * 100).toStringAsFixed(1)} điểm % cơ hội thắng • Accuracy nước này ${item.accuracy.toStringAsFixed(1)}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
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
                    'Nước tốt nhất: ${item.bestMoveSan ?? item.before.bestMove ?? 'không có PV'}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (item.quality.needsSuggestion && item.before.pv.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Biến engine (UCI): ${item.before.pv.take(8).join(' ')}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ),
              if (item.quality.isHeuristic)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Nhãn heuristic: đây là gợi ý, không phải kết luận chắc chắn.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
