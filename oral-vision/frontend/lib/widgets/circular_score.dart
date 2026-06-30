import 'dart:math';
import 'package:flutter/material.dart';

class CircularScore extends StatefulWidget {
  final double score;
  final double size;
  final Color? color;

  const CircularScore({
    super.key,
    required this.score,
    this.size = 100,
    this.color,
  });

  // Risk gradient stops: Low (cyan) -> Medium (purple) -> High (pink)
  static const Color lowRiskColor = Color(0xFF20D3DC);
  static const Color mediumRiskColor = Color(0xFF8B5CF6);
  static const Color highRiskColor = Color(0xFFFF40B4);

  /// NOTE: in this UI, higher score = lower risk (matches "Health Status").
  /// score >= 80 -> healthy/low risk -> cyan
  /// score 50-79 -> moderate -> purple
  /// score < 50  -> at risk/high risk -> pink
  static Color scoreColor(double score) {
    if (score >= 80) return lowRiskColor;
    if (score >= 50) return mediumRiskColor;
    return highRiskColor;
  }

  static String healthLabel(double score) {
    if (score >= 80) return 'Healthy';
    if (score >= 50) return 'Moderate';
    return 'At Risk';
  }

  @override
  State<CircularScore> createState() => _CircularScoreState();
}

class _CircularScoreState extends State<CircularScore>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CircularScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _scoreAnimation = Tween<double>(
        begin: oldWidget.score,
        end: widget.score,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _scoreAnimation,
        builder: (context, _) {
          final animatedScore = _scoreAnimation.value.clamp(0.0, 100.0);
          final displayColor = CircularScore.scoreColor(animatedScore);
          final label = CircularScore.healthLabel(animatedScore);

          return CustomPaint(
            painter: _GradientRingPainter(
              progress: animatedScore / 100,
              strokeWidth: widget.size * 0.1,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    animatedScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: widget.size * 0.24,
                      fontWeight: FontWeight.bold,
                      color: displayColor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: widget.size * 0.11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _GradientRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // White/light track behind the progress ring (per reference design)
    final trackPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Risk gradient arc: cyan -> purple -> pink (low -> medium -> high)
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = const SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + 2 * pi,
      colors: [
        CircularScore.lowRiskColor,
        CircularScore.mediumRiskColor,
        CircularScore.highRiskColor,
      ],
      stops: [0.0, 0.5, 1.0],
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.progress != progress;
}