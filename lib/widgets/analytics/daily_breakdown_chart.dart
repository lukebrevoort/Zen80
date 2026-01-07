import 'package:flutter/material.dart';
import '../../providers/stats_provider.dart' show DailyStats;

/// 7-day bar chart showing signal time per day
///
/// Design: Vertical bars for each day of the week
/// - X-axis: Day abbreviations (M, T, W, T, F, S, S)
/// - Bars colored by ratio (green >= 80%, orange >= 50%, red otherwise)
/// - Today's bar is highlighted
class DailyBreakdownChart extends StatelessWidget {
  final List<DailyStats> dailyStats; // 7 items, Mon-Sun
  final double height;
  final bool showMinutes; // Show minutes below bars vs percentage

  const DailyBreakdownChart({
    super.key,
    required this.dailyStats,
    this.height = 160,
    this.showMinutes = true,
  });

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Color _getRatioColor(double ratio) {
    if (ratio >= 0.8) return Colors.green.shade500;
    if (ratio >= 0.5) return Colors.orange.shade500;
    if (ratio > 0) return Colors.red.shade400;
    return Colors.grey.shade300;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '${hours}h${mins}m';
      return '${hours}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty or invalid data
    if (dailyStats.isEmpty) {
      return _buildEmptyState();
    }

    // Find max minutes for scaling
    final maxMinutes = dailyStats.fold<int>(
      1, // minimum of 1 to avoid division by zero
      (max, stats) => stats.signalMinutes > max ? stats.signalMinutes : max,
    );

    // Bar chart dimensions
    const barWidth = 28.0;
    final barAreaHeight = height - 48; // Leave room for labels

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          // Handle case where we have fewer than 7 days
          final stats = index < dailyStats.length
              ? dailyStats[index]
              : DailyStats.empty(DateTime.now());

          final isToday = _isToday(stats.date);
          final barHeight = maxMinutes > 0
              ? (stats.signalMinutes / maxMinutes * barAreaHeight).clamp(
                  0.0,
                  barAreaHeight,
                )
              : 0.0;

          return _buildDayColumn(
            dayLabel: _dayLabels[index],
            stats: stats,
            barHeight: barHeight,
            maxBarHeight: barAreaHeight,
            barWidth: barWidth,
            isToday: isToday,
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No weekly data',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn({
    required String dayLabel,
    required DailyStats stats,
    required double barHeight,
    required double maxBarHeight,
    required double barWidth,
    required bool isToday,
  }) {
    final color = _getRatioColor(stats.ratio);
    final hasData = stats.signalMinutes > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Value label (above bar)
        SizedBox(
          height: 20,
          child: hasData
              ? Text(
                  showMinutes
                      ? _formatMinutes(stats.signalMinutes)
                      : '${(stats.ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),

        // Bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: barWidth,
          height: barHeight.clamp(hasData ? 4.0 : 0.0, maxBarHeight),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),

        // Day label
        const SizedBox(height: 8),
        Container(
          width: barWidth,
          height: 20,
          decoration: isToday
              ? BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Center(
            child: Text(
              dayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A more detailed daily breakdown with stacked signal/noise visualization
class DailyBreakdownChartDetailed extends StatelessWidget {
  final List<DailyStats> dailyStats;
  final double height;

  const DailyBreakdownChartDetailed({
    super.key,
    required this.dailyStats,
    this.height = 200,
  });

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Color _getSignalColor(double ratio) {
    if (ratio >= 0.8) return Colors.green.shade500;
    if (ratio >= 0.5) return Colors.orange.shade500;
    return Colors.red.shade400;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return _buildEmptyState();
    }

    // Find max focus minutes for scaling
    final maxFocusMinutes = dailyStats.fold<int>(
      1,
      (max, stats) => stats.focusMinutes > max ? stats.focusMinutes : max,
    );

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DailyBreakdownPainter(
          dailyStats: dailyStats,
          maxFocusMinutes: maxFocusMinutes,
          getSignalColor: _getSignalColor,
          isToday: _isToday,
        ),
        child: Column(
          children: [
            Expanded(child: Container()),
            // X-axis labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final stats = index < dailyStats.length
                      ? dailyStats[index]
                      : DailyStats.empty(DateTime.now());
                  final isToday = _isToday(stats.date);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: isToday
                        ? BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    child: Text(
                      _dayLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No weekly data available',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the detailed daily breakdown chart
class _DailyBreakdownPainter extends CustomPainter {
  final List<DailyStats> dailyStats;
  final int maxFocusMinutes;
  final Color Function(double ratio) getSignalColor;
  final bool Function(DateTime date) isToday;

  _DailyBreakdownPainter({
    required this.dailyStats,
    required this.maxFocusMinutes,
    required this.getSignalColor,
    required this.isToday,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width - 48) / 7;
    final barAreaHeight = size.height - 40;
    final startX = 24.0;

    for (int i = 0; i < 7 && i < dailyStats.length; i++) {
      final stats = dailyStats[i];
      final x = startX + i * barWidth + barWidth / 4;
      final barActualWidth = barWidth / 2;

      // Total bar height based on focus minutes
      final totalHeight = maxFocusMinutes > 0
          ? (stats.focusMinutes / maxFocusMinutes * barAreaHeight)
          : 0.0;

      // Signal portion
      final signalHeight = stats.focusMinutes > 0
          ? (stats.signalMinutes / stats.focusMinutes * totalHeight)
          : 0.0;

      final noiseHeight = totalHeight - signalHeight;

      // Draw noise portion (bottom)
      if (noiseHeight > 0) {
        final noisePaint = Paint()..color = Colors.grey.shade300;
        final noiseRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            barAreaHeight - noiseHeight,
            barActualWidth,
            noiseHeight,
          ),
          const Radius.circular(2),
        );
        canvas.drawRRect(noiseRect, noisePaint);
      }

      // Draw signal portion (top)
      if (signalHeight > 0) {
        final signalPaint = Paint()..color = getSignalColor(stats.ratio);
        final signalRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            barAreaHeight - totalHeight,
            barActualWidth,
            signalHeight,
          ),
          const Radius.circular(2),
        );
        canvas.drawRRect(signalRect, signalPaint);
      }

      // Draw today indicator
      if (isToday(stats.date)) {
        final indicatorPaint = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final indicatorRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - 2,
            barAreaHeight - totalHeight - 2,
            barActualWidth + 4,
            totalHeight + 4,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(indicatorRect, indicatorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_DailyBreakdownPainter oldDelegate) {
    return oldDelegate.dailyStats != dailyStats ||
        oldDelegate.maxFocusMinutes != maxFocusMinutes;
  }
}
