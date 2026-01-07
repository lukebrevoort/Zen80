import 'package:flutter/material.dart';
import '../models/daily_summary.dart';

/// Displays the Signal/Noise ratio as a circular progress indicator
///
/// Design: Simple, clean, minimal animation
/// - Only animates when the percentage actually changes
/// - Smooth easing for a refined feel
class RatioIndicator extends StatefulWidget {
  final DailySummary summary;
  final double size;

  const RatioIndicator({super.key, required this.summary, this.size = 180});

  @override
  State<RatioIndicator> createState() => _RatioIndicatorState();
}

class _RatioIndicatorState extends State<RatioIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousPercentage = 0;

  @override
  void initState() {
    super.initState();
    _previousPercentage = widget.summary.signalPercentage;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: _previousPercentage,
      end: _previousPercentage,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(RatioIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newPercentage = widget.summary.signalPercentage;

    // Only animate if percentage changed significantly (more than 0.5%)
    if ((newPercentage - _previousPercentage).abs() > 0.005) {
      _progressAnimation =
          Tween<double>(begin: _previousPercentage, end: newPercentage).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      _controller.forward(from: 0);
      _previousPercentage = newPercentage;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGoldenRatio = widget.summary.goldenRatioAchieved;
    final size = widget.size;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final percentage = _progressAnimation.value.clamp(0.0, 1.0);

        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RatioRingPainter(
              progress: percentage,
              isGoldenRatio: isGoldenRatio,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: size / 4,
                      fontWeight: FontWeight.bold,
                      color: isGoldenRatio
                          ? Colors.green.shade700
                          : Colors.black87,
                    ),
                    child: Text('${(percentage * 100).toInt()}%'),
                  ),
                  Text(
                    'Signal',
                    style: TextStyle(
                      fontSize: size / 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (isGoldenRatio)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: size / 8,
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

/// Custom painter for the progress ring
class _RatioRingPainter extends CustomPainter {
  final double progress;
  final bool isGoldenRatio;

  _RatioRingPainter({required this.progress, required this.isGoldenRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 10.0;

    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = isGoldenRatio ? Colors.green.shade600 : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * (3.14159 / 180); // Start from top
    final sweepAngle = 360 * progress * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RatioRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isGoldenRatio != isGoldenRatio;
  }
}

/// Compact version for history view
class CompactRatioIndicator extends StatelessWidget {
  final DailySummary summary;

  const CompactRatioIndicator({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final percentage = summary.signalPercentage.clamp(0.0, 1.0);
    final isGoldenRatio = summary.goldenRatioAchieved;

    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _CompactRatioRingPainter(
          progress: percentage,
          isGoldenRatio: isGoldenRatio,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isGoldenRatio ? Colors.green.shade700 : Colors.black87,
                ),
              ),
              if (isGoldenRatio)
                Icon(Icons.check, size: 12, color: Colors.green.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the compact progress ring
class _CompactRatioRingPainter extends CustomPainter {
  final double progress;
  final bool isGoldenRatio;

  _CompactRatioRingPainter({
    required this.progress,
    required this.isGoldenRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 5.0;

    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = isGoldenRatio ? Colors.green.shade600 : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * (3.14159 / 180); // Start from top
    final sweepAngle = 360 * progress * (3.14159 / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CompactRatioRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isGoldenRatio != isGoldenRatio;
  }
}
