import 'package:flutter/material.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/usecases/classify_move.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';

class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.evaluation,
    required this.height,
    this.flipped = false,
  });
  final PositionEval? evaluation;
  final double height;
  final bool flipped;
  @override
  Widget build(BuildContext context) {
    if (evaluation == null) {
      return Tooltip(
        message: 'Chưa có đánh giá cho vị trí này',
        child: Container(
          width: 28,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF34424C),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(child: Text('—')),
        ),
      );
    }
    final white = (EvaluationMath.winPercent(evaluation!.cpWhite) * 100)
        .round()
        .clamp(1, 9999);
    final segments = [
      Expanded(
        flex: 10000 - white,
        child: const ColoredBox(color: Color(0xFF34424C)),
      ),
      Expanded(
        flex: white,
        child: const ColoredBox(color: Color(0xFFEDEFE6)),
      ),
    ];
    return Tooltip(
      message: 'Điểm từ phía Trắng: ${evaluationLabel(evaluation!)}',
      child: SizedBox(
        width: 28,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: flipped ? segments.reversed.toList() : segments,
          ),
        ),
      ),
    );
  }
}
