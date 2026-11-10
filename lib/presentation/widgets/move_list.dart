import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';

class MoveList extends StatefulWidget {
  const MoveList({
    super.key,
    required this.moves,
    required this.selectedPly,
    required this.onSelect,
    this.fillHeight = false,
  });
  final List<MoveAnalysis> moves;
  final int selectedPly;
  final ValueChanged<int> onSelect;
  final bool fillHeight;
  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _scroll = ScrollController();
  double _rowExtent = 0;
  double _viewportHeight = 0;
  int? _lastSelectedPly;

  static const _moveStyle = TextStyle(fontSize: 16, height: 1.25);
  static const _evalStyle = TextStyle(
    fontSize: 11,
    height: 1.25,
    color: AppTheme.muted,
  );

  String _moveLabel(MoveAnalysis analysis) {
    final move = analysis.move;
    return '${move.moveNumber}${move.side == ChessSide.white ? '.' : '...'} ${move.san}';
  }

  Size _textSize(
    String text,
    TextStyle style, {
    double width = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  void _keepSelectionVisible(double extent, double viewportHeight) {
    final resized = _rowExtent != extent || _viewportHeight != viewportHeight;
    if (!resized && _lastSelectedPly == widget.selectedPly) return;
    _rowExtent = extent;
    _viewportHeight = viewportHeight;
    _lastSelectedPly = widget.selectedPly;
    // Wait for the list to lay out with its new row height before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final target =
          ((widget.selectedPly - 1) * _rowExtent -
                  (position.viewportDimension - _rowExtent) / 2)
              .clamp(0.0, position.maxScrollExtent);
      if (resized) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = math.max(1.0, box.maxWidth - 24);
      final titles = widget.moves.map(_moveLabel).toList();
      double titleWidth = 0, evalWidth = 0, evalHeight = 0;
      for (final analysis in widget.moves) {
        final title = _textSize(
          _moveLabel(analysis),
          _moveStyle.copyWith(fontWeight: FontWeight.bold),
        );
        final evaluation = _textSize(
          evaluationLabel(analysis.after),
          _evalStyle,
        );
        titleWidth = math.max(titleWidth, title.width);
        evalWidth = math.max(evalWidth, evaluation.width);
        evalHeight = math.max(evalHeight, evaluation.height);
      }
      double chipWidth = 0, chipHeight = 0;
      for (final quality in MoveQuality.values) {
        final size = _textSize(
          quality.label,
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          width: math.max(1.0, width - 16),
        );
        chipWidth = math.max(chipWidth, size.width + 16);
        chipHeight = math.max(chipHeight, size.height + 8);
      }
      final compact = titleWidth + chipWidth + evalWidth + 24 > width;
      final titleSpace = compact ? width : width - chipWidth - evalWidth - 24;
      double titleHeight = 0;
      for (final title in titles) {
        titleHeight = math.max(
          titleHeight,
          _textSize(
            title,
            _moveStyle.copyWith(fontWeight: FontWeight.bold),
            width: titleSpace,
          ).height,
        );
      }
      final footerHeight = chipWidth + evalWidth + 12 > width
          ? chipHeight + 6 + evalHeight
          : math.max(chipHeight, evalHeight);
      // Measure actual text so neither large fonts nor long SAN get clipped.
      // One shared extent also keeps jump-to-move accurate after resizing.
      final extent = math.max(
        52.0,
        16.0 +
            (compact
                ? titleHeight + 8 + footerHeight
                : math.max(titleHeight, math.max(chipHeight, evalHeight))),
      );
      final height = widget.fillHeight ? box.maxHeight : 360.0;
      _keepSelectionVisible(extent, math.min(height, box.maxHeight));

      return SizedBox(
        height: height,
        child: ListView.builder(
          key: const Key('move-list'),
          controller: _scroll,
          itemExtent: extent,
          itemCount: widget.moves.length,
          itemBuilder: (context, index) {
            final analysis = widget.moves[index];
            final selected = widget.selectedPly == index + 1;
            final title = Text(
              titles[index],
              style: _moveStyle.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            );
            final chip = QualityChip(analysis.quality);
            final evaluation = Text(
              evaluationLabel(analysis.after),
              style: _evalStyle,
            );
            return Material(
              color: selected
                  ? AppTheme.accent.withValues(alpha: .10)
                  : Colors.transparent,
              child: InkWell(
                key: ValueKey('move-${index + 1}'),
                onTap: () => widget.onSelect(index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            title,
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [chip, evaluation],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 12),
                            chip,
                            const SizedBox(width: 12),
                            evaluation,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
