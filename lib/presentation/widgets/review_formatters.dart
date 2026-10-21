import 'package:flutter/material.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';

extension QualityStyle on MoveQuality {
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
  Color get color => switch (this) {
    MoveQuality.brilliant => const Color(0xFF6EE7DD),
    MoveQuality.great => const Color(0xFF91B6F7),
    MoveQuality.best => const Color(0xFF9DCC9C),
    MoveQuality.excellent => const Color(0xFFB4C995),
    MoveQuality.good => const Color(0xFFBEC7B5),
    MoveQuality.book => const Color(0xFFC4AC83),
    MoveQuality.inaccuracy => const Color(0xFFF0CB72),
    MoveQuality.mistake => const Color(0xFFEFA36D),
    MoveQuality.miss => const Color(0xFFE891AF),
    MoveQuality.blunder => const Color(0xFFF17C7C),
  };
}

String evaluationLabel(PositionEval evaluation) {
  if (evaluation.mateWhite != null) {
    return '${evaluation.cpWhite < 0 ? '−' : '+'}M${evaluation.mateWhite!.abs()}';
  }
  final pawns = evaluation.cpWhite / 100;
  return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(2)}';
}

String clockLabel(Duration? clock) {
  if (clock == null) return '—';
  final hours = clock.inHours;
  final minutes = (clock.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (clock.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class QualityChip extends StatelessWidget {
  const QualityChip(this.quality, {super.key});
  final MoveQuality quality;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: quality.color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        quality.label,
        style: TextStyle(
          color: quality.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
