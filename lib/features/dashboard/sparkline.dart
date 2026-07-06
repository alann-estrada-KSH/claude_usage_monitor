import 'package:flutter/material.dart';

import 'usage_bar.dart' show severityColor;

/// A single-line console/LED meter -- one row of discrete square cells
/// (like `htop`'s `[|||...   ]` bars) filled left to right up to
/// [percent], the rest left dim. One line, one value: this is the whole
/// meter, not a history plot -- keeps the "pro console" look compact
/// instead of a multi-row chart. `null` renders as fully dim (no reading
/// yet). Filled cells are colored per [severityColor].
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.percent, this.height = 20});

  final double? percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = percent == null ? null : severityColor(context, percent!);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: CustomPaint(
        painter: _MeterPainter(percent, color, colorScheme.outlineVariant),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.percent, this.color, this.gridColor);

  final double? percent;
  final Color? color;
  final Color gridColor;

  // One segment per percentage point, so the meter's fill lines up exactly
  // with the number shown next to it.
  static const _segmentCount = 100;
  static const _segmentGap = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final segmentWidth = (size.width - _segmentGap * (_segmentCount - 1)) / _segmentCount;
    final emptyPaint = Paint()..color = gridColor.withValues(alpha: 0.35);
    final filledSegments =
        percent == null ? 0 : (_segmentCount * (percent!.clamp(0, 100)) / 100).round();

    for (var c = 0; c < _segmentCount; c++) {
      final left = c * (segmentWidth + _segmentGap);
      final filledPaint = color == null || c >= filledSegments ? null : (Paint()..color = color!);
      canvas.drawRect(
        Rect.fromLTWH(left, 0, segmentWidth, size.height),
        filledPaint ?? emptyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}
