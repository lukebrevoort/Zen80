import 'dart:math' as math;

import 'package:flutter/material.dart';

class FocusHoursDial extends StatefulWidget {
  final int hours;
  final int minHours;
  final int maxHours;
  final double size;
  final ValueChanged<int> onChanged;
  final bool showSlider;

  const FocusHoursDial({
    super.key,
    required this.hours,
    required this.onChanged,
    this.minHours = 1,
    this.maxHours = 12,
    this.size = 180,
    this.showSlider = true,
  });

  @override
  State<FocusHoursDial> createState() => _FocusHoursDialState();
}

class _FocusHoursDialState extends State<FocusHoursDial> {
  void _updateFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final vector = localPosition - center;
    if (vector.distance < 12) return;

    final angle = math.atan2(vector.dy, vector.dx);
    double adjusted = angle + math.pi / 2;
    if (adjusted < 0) {
      adjusted += math.pi * 2;
    }

    final ratio = adjusted / (math.pi * 2);
    var value = (ratio * widget.maxHours).round();
    if (value == 0) value = widget.maxHours;
    value = value.clamp(widget.minHours, widget.maxHours);

    if (value != widget.hours) {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.hours / widget.maxHours;

    return Column(
      children: [
        GestureDetector(
          onTapDown: (details) => _updateFromOffset(
            details.localPosition,
            Size(widget.size, widget.size),
          ),
          onPanUpdate: (details) => _updateFromOffset(
            details.localPosition,
            Size(widget.size, widget.size),
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _DialPainter(progress: progress, ticks: widget.maxHours),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.hours}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.hours == 1 ? 'hour / day' : 'hours / day',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showSlider) ...[
          const SizedBox(height: 12),
          Slider(
            value: widget.hours.toDouble(),
            min: widget.minHours.toDouble(),
            max: widget.maxHours.toDouble(),
            divisions: widget.maxHours - widget.minHours,
            label: '${widget.hours}h',
            onChanged: (value) => widget.onChanged(value.round()),
            activeColor: Colors.black,
            inactiveColor: Colors.grey.shade300,
          ),
        ],
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final int ticks;

  _DialPainter({required this.progress, required this.ticks});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    for (int i = 0; i < ticks; i++) {
      final angle = startAngle + (math.pi * 2 * i / ticks);
      final inner = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + (radius + 2) * math.cos(angle),
        center.dy + (radius + 2) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ticks != ticks;
  }
}
