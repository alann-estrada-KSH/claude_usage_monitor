import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/usage_history_point.dart';

class UsageHistoryChart extends StatelessWidget {
  const UsageHistoryChart({super.key, required this.points});

  final List<UsageHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(
        painter: _HistoryPainter(
          points,
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.tertiary,
          Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(
    this.points,
    this.fiveHourColor,
    this.weeklyColor,
    this.gridColor,
  );

  final List<UsageHistoryPoint> points;
  final Color fiveHourColor;
  final Color weeklyColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = gridColor.withValues(alpha: 0.5);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );
    _drawSeries(
      canvas,
      size,
      points.map((point) => point.fiveHourPercent).toList(),
      fiveHourColor,
    );
    _drawSeries(
      canvas,
      size,
      points.map((point) => point.weeklyPercent).toList(),
      weeklyColor,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double?> values,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        started = false;
        continue;
      }
      final x = values.length == 1
          ? 0.0
          : size.width * index / (values.length - 1);
      final y = size.height * (1 - math.max(0, math.min(100, value)) / 100);
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.fiveHourColor != fiveHourColor ||
      oldDelegate.weeklyColor != weeklyColor;
}
