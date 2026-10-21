import 'package:flutter/material.dart';
import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';

class EvalChart extends StatelessWidget {
  const EvalChart({
    super.key,
    required this.evaluations,
    required this.selectedPly,
    required this.onSelect,
  });
  final List<PositionEval> evaluations;
  final int selectedPly;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Biểu đồ đánh giá. Bấm một điểm để xem vị trí tương ứng.',
    child: SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final fraction =
                ((details.localPosition.dx - 32) / (constraints.maxWidth - 44))
                    .clamp(0.0, 1.0);
            onSelect((fraction * (evaluations.length - 1)).round());
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(evaluations, selectedPly),
          ),
        ),
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.evaluations, this.selected);
  final List<PositionEval> evaluations;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(32, 12, size.width - 12, size.height - 20);
    final grid = Paint()
      ..color = const Color(0xFF35424D)
      ..strokeWidth = 1;
    void label(String text, Offset at) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at);
    }

    for (final fraction in [0.0, .5, 1.0]) {
      final y = rect.top + rect.height * fraction;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    label('+10', Offset(0, rect.top - 5));
    label('0', Offset(12, rect.center.dy - 5));
    label('−10', Offset(0, rect.bottom - 5));
    label('0', Offset(rect.left, rect.bottom + 5));
    label(
      '${evaluations.length - 1} ply',
      Offset(rect.right - 36, rect.bottom + 5),
    );
    if (evaluations.length < 2) return;
    final points = [
      for (var i = 0; i < evaluations.length; i++)
        Offset(
          rect.left + i / (evaluations.length - 1) * rect.width,
          rect.center.dy -
              evaluations[i].cpWhite.clamp(-1000, 1000) /
                  1000 *
                  rect.height /
                  2,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(path)
      ..lineTo(rect.right, rect.center.dy)
      ..lineTo(rect.left, rect.center.dy)
      ..close();
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawPath(
      fill,
      Paint()..color = AppTheme.accent.withValues(alpha: .10),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
    final point = points[selected.clamp(0, points.length - 1)];
    canvas.drawLine(
      Offset(point.dx, rect.top),
      Offset(point.dx, rect.bottom),
      Paint()..color = AppTheme.accent.withValues(alpha: .5),
    );
    canvas.drawCircle(point, 4, Paint()..color = AppTheme.accent);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.evaluations != evaluations ||
      oldDelegate.selected != selected;
}
