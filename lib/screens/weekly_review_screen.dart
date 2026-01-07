import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/stats_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/analytics/ratio_ring_chart.dart';

/// Weekly review screen displaying analytics with charts and stats
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  DateTime _currentWeekStart = WeeklyStats.getWeekStart(DateTime.now());

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    final now = WeeklyStats.getWeekStart(DateTime.now());
    if (!nextWeek.isAfter(now)) {
      setState(() {
        _currentWeekStart = nextWeek;
      });
    }
  }

  bool get _canGoNext {
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    final now = WeeklyStats.getWeekStart(DateTime.now());
    return !nextWeek.isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();
    final tagProvider = context.watch<TagProvider>();

    final weeklyStats = statsProvider.getStatsForWeek(_currentWeekStart);
    final dailyStats = statsProvider.getDailyBreakdown(_currentWeekStart);

    final hasActivity =
        weeklyStats.totalFocusMinutes > 0 ||
        weeklyStats.completedTasksCount > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Weekly Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: hasActivity
            ? _buildContent(weeklyStats, dailyStats, tagProvider)
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildContent(
    WeeklyStats weeklyStats,
    List<DailyStats> dailyStats,
    TagProvider tagProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Week Navigation Header
          _buildWeekNavigationHeader(weeklyStats),
          const SizedBox(height: 24),

          // Main Ratio Display
          _buildRatioSection(weeklyStats),
          const SizedBox(height: 24),

          // Stats Summary Row
          _buildStatsSummaryRow(weeklyStats),
          const SizedBox(height: 32),

          // Daily Breakdown Section
          _buildSectionHeader('Daily Breakdown'),
          const SizedBox(height: 16),
          _DailyBreakdownChart(dailyStats: dailyStats),
          const SizedBox(height: 32),

          // Tag Breakdown Section
          _buildSectionHeader('Time by Tag'),
          const SizedBox(height: 16),
          _buildTagBreakdown(weeklyStats, tagProvider),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWeekNavigationHeader(WeeklyStats weeklyStats) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: Icon(Icons.chevron_left, color: Colors.grey.shade700),
            tooltip: 'Previous week',
          ),
          const SizedBox(width: 8),
          Text(
            weeklyStats.formattedDateRange,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _canGoNext ? _nextWeek : null,
            icon: Icon(
              Icons.chevron_right,
              color: _canGoNext ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            tooltip: _canGoNext ? 'Next week' : 'Current week',
          ),
        ],
      ),
    );
  }

  Widget _buildRatioSection(WeeklyStats weeklyStats) {
    return Column(
      children: [
        // Main Ring Chart
        Center(
          child: RatioRingChart(ratio: weeklyStats.signalNoiseRatio, size: 180),
        ),

        // Golden Ratio Achievement
        if (weeklyStats.goldenRatioAchieved) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Golden Ratio Achieved!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSummaryRow(WeeklyStats weeklyStats) {
    return Row(
      children: [
        Expanded(
          child: _StatsSummaryCard(
            label: 'Signal Time',
            value: weeklyStats.formattedSignalTime,
            icon: Icons.bolt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatsSummaryCard(
            label: 'Tasks Done',
            value: weeklyStats.completedTasksCount.toString(),
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatsSummaryCard(
            label: 'Signal Ratio',
            value: '${weeklyStats.signalPercentage.toInt()}%',
            icon: Icons.pie_chart_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTagBreakdown(WeeklyStats weeklyStats, TagProvider tagProvider) {
    if (weeklyStats.tagBreakdown.isEmpty) {
      return _buildTagEmptyState();
    }

    // Convert tagProvider.tags to a Map<String, Tag> for the chart
    final tagsMap = {for (final tag in tagProvider.tags) tag.id: tag};

    return _TagBreakdownChart(
      tagMinutes: weeklyStats.tagBreakdown,
      tags: tagsMap,
    );
  }

  Widget _buildTagEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.label_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No tags used this week',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add tags to your tasks to see time breakdown',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Week Navigation (still allow navigating)
            _buildWeekNavigationHeader(
              WeeklyStats(weekStartDate: _currentWeekStart),
            ),
            const SizedBox(height: 40),

            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No activity this week',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete Signal tasks to see your stats here',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stats summary card widget for displaying a single metric
class _StatsSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _StatsSummaryCard({
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Daily breakdown chart showing 7 days of the week
class _DailyBreakdownChart extends StatelessWidget {
  final List<DailyStats> dailyStats;

  const _DailyBreakdownChart({required this.dailyStats});

  String _getDayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Find max signal minutes for scaling
    final maxMinutes = dailyStats.fold<int>(
      60, // minimum 1 hour for scale
      (max, stat) => stat.signalMinutes > max ? stat.signalMinutes : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Bar chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyStats.map((stat) {
                // Calculate bar height as percentage of available space
                // We use 110 as max bar height to leave room for label
                const maxBarHeight = 110.0;
                final barHeight = maxMinutes > 0
                    ? (stat.signalMinutes / maxMinutes) * maxBarHeight
                    : 0.0;
                final isGolden = stat.goldenRatioAchieved;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: barHeight.clamp(4.0, maxBarHeight),
                          decoration: BoxDecoration(
                            color: isGolden
                                ? Colors.green.shade500
                                : stat.signalMinutes > 0
                                ? Colors.blue.shade400
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Day label
                        Text(
                          _getDayLabel(stat.date),
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.0,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green.shade500, '80%+ Signal'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue.shade400, 'Signal Time'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// Tag breakdown chart showing time spent per tag
class _TagBreakdownChart extends StatelessWidget {
  final Map<String, int> tagMinutes;
  final Map<String, Tag> tags;

  const _TagBreakdownChart({required this.tagMinutes, required this.tags});

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort entries by minutes descending
    final sortedEntries = tagMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate total for percentages
    final totalMinutes = sortedEntries.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final tagEntry = entry.value;
          final tag = tags[tagEntry.key];
          final minutes = tagEntry.value;
          final percentage = totalMinutes > 0
              ? (minutes / totalMinutes * 100).toInt()
              : 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: index < sortedEntries.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                  : null,
            ),
            child: Row(
              children: [
                // Tag color dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tag?.color ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),

                // Tag name
                Expanded(
                  child: Text(
                    tag?.name ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Time
                Text(
                  _formatMinutes(minutes),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),

                // Percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (tag?.color ?? Colors.grey).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tag?.color ?? Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
