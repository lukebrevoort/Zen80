import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A ring/arc chart showing Signal percentage (0-100%)
///
/// Design: Minimalist ring chart with large percentage in center
/// - Ring shows filled portion = ratio, unfilled = noise
/// - Golden star indicator when ratio >= 0.8 (80/20 achieved!)
class RatioRingChart extends StatefulWidget {
  final double ratio; // 0.0 to 1.0
  final double size; // widget size (default 200)
  final Color? signalColor; // green-ish for signal
  final Color? noiseColor; // gray for noise
  final bool showAnimation; // animate on first render

  const RatioRingChart({
    super.key,
    required this.ratio,
    this.size = 200,
    this.signalColor,
    this.noiseColor,
    this.showAnimation = true,
  });

  @override
  State<RatioRingChart> createState() => _RatioRingChartState();
}

class _RatioRingChartState extends State<RatioRingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousRatio = 0;

  @override
  void initState() {
    super.initState();
    _previousRatio = widget.showAnimation ? 0 : widget.ratio;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: _previousRatio,
      end: widget.ratio,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.showAnimation) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RatioRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newRatio = widget.ratio;

    // Only animate if ratio changed significantly (more than 0.5%)
    if ((newRatio - _previousRatio).abs() > 0.005) {
      _progressAnimation = Tween<double>(begin: _previousRatio, end: newRatio)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      _controller.forward(from: 0);
      _previousRatio = newRatio;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSignalColor(double ratio) {
    if (ratio >= 0.8) return Colors.green.shade600;
    if (ratio >= 0.5) return Colors.orange.shade600;
    return Colors.red.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final noiseColor = widget.noiseColor ?? Colors.grey.shade200;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final ratio = _progressAnimation.value.clamp(0.0, 1.0);
        final signalColor = widget.signalColor ?? _getSignalColor(ratio);
        final isGoldenRatio = ratio >= 0.8;
        final percentage = (ratio * 100).toInt();

        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RatioRingPainter(
              progress: ratio,
              signalColor: signalColor,
              noiseColor: noiseColor,
              strokeWidth: size / 12,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Golden star for 80/20 achieved
                  if (isGoldenRatio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber.shade600,
                        size: size / 8,
                      ),
                    ),

                  // Large percentage
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: size / 4,
                      fontWeight: FontWeight.bold,
                      color: isGoldenRatio
                          ? Colors.green.shade700
                          : Colors.black87,
                    ),
                  ),

                  // "Signal" label
                  Text(
                    'Signal',
                    style: TextStyle(
                      fontSize: size / 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // "80/20 achieved!" indicator
                  if (isGoldenRatio)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '80/20 achieved!',
                          style: TextStyle(
                            fontSize: size / 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the ratio ring
class _RatioRingPainter extends CustomPainter {
  final double progress;
  final Color signalColor;
  final Color noiseColor;
  final double strokeWidth;

  _RatioRingPainter({
    required this.progress,
    required this.signalColor,
    required this.noiseColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2 - 8;

    // Background ring (noise portion)
    final backgroundPaint = Paint()
      ..color = noiseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring (signal portion)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = signalColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // Start from top
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RatioRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.signalColor != signalColor ||
        oldDelegate.noiseColor != noiseColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Compact version of the ratio ring for list views
class CompactRatioRingChart extends StatelessWidget {
  final double ratio;
  final double size;

  const CompactRatioRingChart({super.key, required this.ratio, this.size = 48});

  Color _getSignalColor(double ratio) {
    if (ratio >= 0.8) return Colors.green.shade600;
    if (ratio >= 0.5) return Colors.orange.shade600;
    return Colors.red.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    final percentage = (clampedRatio * 100).toInt();
    final isGoldenRatio = clampedRatio >= 0.8;
    final signalColor = _getSignalColor(clampedRatio);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RatioRingPainter(
          progress: clampedRatio,
          signalColor: signalColor,
          noiseColor: Colors.grey.shade200,
          strokeWidth: size / 10,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: size / 3.5,
                  fontWeight: FontWeight.bold,
                  color: isGoldenRatio ? Colors.green.shade700 : Colors.black87,
                ),
              ),
              if (isGoldenRatio)
                Icon(Icons.star, size: size / 5, color: Colors.amber.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
