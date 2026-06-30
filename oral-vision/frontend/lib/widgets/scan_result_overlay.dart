import 'package:flutter/material.dart';

/// Draws bbox overlays and optional affected-area grid on scan images.
class ScanResultOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> bboxes;
  final List<List<double>>? maskGrid;
  final double displayWidth;
  final double displayHeight;
  final int? sourceWidth;
  final int? sourceHeight;

  const ScanResultOverlay({
    super.key,
    required this.bboxes,
    this.maskGrid,
    required this.displayWidth,
    required this.displayHeight,
    this.sourceWidth,
    this.sourceHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(displayWidth, displayHeight),
      painter: _ScanOverlayPainter(
        bboxes: bboxes,
        maskGrid: maskGrid,
        displayWidth: displayWidth,
        displayHeight: displayHeight,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final List<Map<String, dynamic>> bboxes;
  final List<List<double>>? maskGrid;
  final double displayWidth;
  final double displayHeight;
  final int? sourceWidth;
  final int? sourceHeight;

  _ScanOverlayPainter({
    required this.bboxes,
    this.maskGrid,
    required this.displayWidth,
    required this.displayHeight,
    this.sourceWidth,
    this.sourceHeight,
  });

  double _scaleX() {
    final sw = sourceWidth ?? displayWidth;
    return displayWidth / sw;
  }

  double _scaleY() {
    final sh = sourceHeight ?? displayHeight;
    return displayHeight / sh;
  }

  double _normCoord(num? v, num fallback) {
    final d = (v ?? fallback).toDouble();
    if (d <= 1.0) return d;
    return d;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (maskGrid != null && maskGrid!.isNotEmpty) {
      final rows = maskGrid!.length;
      final cols = maskGrid!.first.length;
      final cellW = displayWidth / cols;
      final cellH = displayHeight / rows;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final val = maskGrid![r][c];
          if (val <= 0.05) continue;
          final paint = Paint()
            ..color = Colors.red.withValues(alpha: (0.15 + val * 0.55).clamp(0.0, 0.7))
            ..style = PaintingStyle.fill;
          canvas.drawRect(Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH), paint);
          if (val >= 0.35) {
            final border = Paint()
              ..color = Colors.red.withValues(alpha: 0.85)
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke;
            canvas.drawRect(Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH), border);
          }
        }
      }
    }

    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.cyan,
    ];
    final sx = _scaleX();
    final sy = _scaleY();

    for (var i = 0; i < bboxes.length; i++) {
      final box = bboxes[i];
      final sw = sourceWidth?.toDouble() ?? displayWidth;
      final sh = sourceHeight?.toDouble() ?? displayHeight;

      double x1 = _normCoord(box['x1'], 0);
      double y1 = _normCoord(box['y1'], 0);
      double x2 = _normCoord(box['x2'], 0);
      double y2 = _normCoord(box['y2'], 0);

      if (x2 <= 1.0 && y2 <= 1.0) {
        x1 *= displayWidth;
        y1 *= displayHeight;
        x2 *= displayWidth;
        y2 *= displayHeight;
      } else {
        x1 *= sx;
        y1 *= sy;
        x2 *= sx;
        y2 *= sy;
      }

      final color = colors[i % colors.length];
      canvas.drawRect(
        Rect.fromLTRB(x1, y1, x2, y2),
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );

      final conf = ((box['confidence'] as num?)?.toDouble() ?? 0);
      final confPct = conf <= 1 ? (conf * 100).toStringAsFixed(0) : conf.toStringAsFixed(0);
      final label = 'R${i + 1} · $confPct%';
      final labelY = y1 > 22 ? y1 - 22 : y1 + 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, labelY, label.length * 7.5 + 8, 20),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(x1 + 4, labelY + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => true;
}
