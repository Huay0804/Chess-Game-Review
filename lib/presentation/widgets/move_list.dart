import 'package:flutter/material.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';

class MoveList extends StatefulWidget {
  const MoveList({
    super.key,
    required this.moves,
    required this.selectedPly,
    required this.onSelect,
  });
  final List<MoveAnalysis> moves;
  final int selectedPly;
  final ValueChanged<int> onSelect;
  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(covariant MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPly != oldWidget.selectedPly && _scroll.hasClients) {
      final target = ((widget.selectedPly - 1) * 52.0 - 130).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: ListView.builder(
      key: const Key('move-list'),
      controller: _scroll,
      itemExtent: 52,
      itemCount: widget.moves.length,
      itemBuilder: (context, index) {
        final analysis = widget.moves[index];
        final move = analysis.move;
        final selected = widget.selectedPly == index + 1;
        return Material(
          color: selected
              ? AppTheme.accent.withValues(alpha: .10)
              : Colors.transparent,
          child: InkWell(
            key: ValueKey('move-${index + 1}'),
            onTap: () => widget.onSelect(index + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${move.moveNumber}${move.side == ChessSide.white ? '.' : '...'}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      move.san,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  QualityChip(analysis.quality),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    child: Text(
                      evaluationLabel(analysis.after),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
