import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/equalizer_settings.dart';

class EqualizerGraph extends StatelessWidget {
  final List<EqualizerBand> bands;
  final ValueChanged<int>? onBandSelected;
  final bool isEnabled;

  const EqualizerGraph({
    super.key,
    required this.bands,
    this.onBandSelected,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: CustomPaint(
        painter: _EqualizerGraphPainter(
          bands: bands,
          isEnabled: isEnabled,
          isDark: isDark,
        ),
        child: Container(),
      ),
    );
  }
}

class _EqualizerGraphPainter extends CustomPainter {
  final List<EqualizerBand> bands;
  final bool isEnabled;
  final bool isDark;

  _EqualizerGraphPainter({
    required this.bands,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(18)
      ..strokeWidth = 1.0;

    final centerLinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(35)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines: +12dB, +6dB, 0dB, -6dB, -12dB
    final stepY = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = i * stepY;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i == 2 ? centerLinePaint : gridPaint,
      );
    }

    // Draw dB labels (+12db, 0db, -12db)
    _drawText(canvas, '+12dB', const Offset(4, 2));
    _drawText(canvas, '0dB', Offset(4, size.height / 2 - 6));
    _drawText(canvas, '-12dB', Offset(4, size.height - 14));

    if (bands.isEmpty) return;

    // Calculate band point coordinates
    final points = <Offset>[];
    final stepX = size.width / (bands.length + 1);

    for (int i = 0; i < bands.length; i++) {
      final x = (i + 1) * stepX;
      // gain is -12 to +12
      final gainNorm = (bands[i].gain / 12.0).clamp(-1.0, 1.0);
      final y = size.height / 2 - (gainNorm * (size.height / 2 - 12));
      points.add(Offset(x, y));
    }

    // Draw smooth curve connecting the points
    final curvePath = Path();
    curvePath.moveTo(0, size.height / 2);
    curvePath.lineTo(points.first.dx * 0.5, (size.height / 2 + points.first.dy) / 2);

    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        curvePath.lineTo(points[i].dx, points[i].dy);
      } else {
        final p0 = points[i - 1];
        final p1 = points[i];
        final midX = (p0.dx + p1.dx) / 2;
        curvePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
    }
    curvePath.lineTo(size.width, size.height / 2);

    final linePaint = Paint()
      ..color = isEnabled ? AppColors.primary : Colors.grey
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(curvePath, linePaint);

    // Draw circles and frequency labels at each node
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final nodeOuterPaint = Paint()
        ..color = isEnabled ? AppColors.primary : Colors.grey
        ..style = PaintingStyle.fill;

      final nodeInnerPaint = Paint()
        ..color = isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pt, 6.0, nodeOuterPaint);
      canvas.drawCircle(pt, 3.5, nodeInnerPaint);

      // Draw frequency label at bottom
      _drawFreqLabel(canvas, bands[i].label, Offset(pt.dx, size.height - 12));
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withAlpha(100),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawFreqLabel(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withAlpha(140),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _EqualizerGraphPainter oldDelegate) {
    return true;
  }
}
