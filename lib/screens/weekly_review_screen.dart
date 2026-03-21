import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/stats_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/analytics/ratio_ring_chart.dart';

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
    final weekTasks = statsProvider.getTasksForWeek(_currentWeekStart);
    final previousWeekStats = statsProvider.getStatsForWeek(
      _currentWeekStart.subtract(const Duration(days: 7)),
    );
    final goalMinutesPerDay = statsProvider.focusMinutesPerDay;

    final hasActivity =
        weeklyStats.totalSignalMinutes > 0 ||
        weeklyStats.completedTasksCount > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Weekly Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: hasActivity
                ? () => _exportSummary(
                    context,
                    weeklyStats,
                    previousWeekStats,
                    goalMinutesPerDay,
                    weekTasks,
                  )
                : null,
            tooltip: 'Export summary',
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: hasActivity
            ? _buildContent(
                context,
                weeklyStats,
                previousWeekStats,
                dailyStats,
                weekTasks,
                goalMinutesPerDay,
                tagProvider,
              )
            : _buildEmptyState(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WeeklyStats weeklyStats,
    WeeklyStats previousWeekStats,
    List<DailyStats> dailyStats,
    List<SignalTask> weekTasks,
    int goalMinutesPerDay,
    TagProvider tagProvider,
  ) {
    final planningData = _PlanningAccuracyData.fromTasks(weekTasks);
    final avgDailyMinutes = (weeklyStats.totalSignalMinutes / 7).round();
    final goalProgress = goalMinutesPerDay > 0
        ? (avgDailyMinutes / goalMinutesPerDay).clamp(0.0, 1.6)
        : 0.0;

    final tagTrendSeries = _buildTagTrendSeries(
      context.read<StatsProvider>(),
      _currentWeekStart,
      4,
      weeklyStats.tagBreakdown.keys.take(4).toList(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildWeekNavigationHeader(weeklyStats),
          const SizedBox(height: 20),
          _HeroInsightsCard(
            weeklyStats: weeklyStats,
            averageDailySignalMinutes: avgDailyMinutes,
            goalMinutesPerDay: goalMinutesPerDay,
            goalProgress: goalProgress,
          ),
          const SizedBox(height: 16),
          _buildStatsSummaryRow(weeklyStats),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Week-over-week'),
          const SizedBox(height: 12),
          _WeekComparisonCard(
            currentWeek: weeklyStats,
            previousWeek: previousWeekStats,
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Daily Insights'),
          const SizedBox(height: 12),
          _DailyInsightsChart(
            dailyStats: dailyStats,
            goalMinutesPerDay: goalMinutesPerDay,
            onDayTap: (date) {
              final tasks = context.read<StatsProvider>().getTasksForDay(date);
              _showDailyDetailSheet(context, date, goalMinutesPerDay, tasks);
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Planning Accuracy'),
          const SizedBox(height: 12),
          _PlanningAccuracyCard(data: planningData),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Tag Trends'),
          const SizedBox(height: 12),
          _TagTrendCard(series: tagTrendSeries, tagProvider: tagProvider),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Time by Tag'),
          const SizedBox(height: 12),
          _buildTagBreakdown(weeklyStats, tagProvider),
          const SizedBox(height: 24),
          _ExportCard(
            onPressed: () => _exportSummary(
              context,
              weeklyStats,
              previousWeekStats,
              goalMinutesPerDay,
              weekTasks,
            ),
          ),
          const SizedBox(height: 36),
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

  Widget _buildTagBreakdown(WeeklyStats weeklyStats, TagProvider tagProvider) {
    if (weeklyStats.tagBreakdown.isEmpty) {
      return _buildTagEmptyState();
    }

    final tagsMap = {for (final tag in tagProvider.tags) tag.id: tag};
    return _TagBreakdownChart(
      tagMinutes: weeklyStats.tagBreakdown,
      tags: tagsMap,
    );
  }

  Widget _buildTagEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
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
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add tags to tasks to unlock trend insights',
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
              'Complete Signal tasks to unlock weekly insights',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<_TagTrendSeries> _buildTagTrendSeries(
    StatsProvider statsProvider,
    DateTime currentWeekStart,
    int weeks,
    List<String> preferredTagIds,
  ) {
    final weekStarts = List.generate(
      weeks,
      (index) =>
          currentWeekStart.subtract(Duration(days: (weeks - 1 - index) * 7)),
    );
    final statsByWeek = {
      for (final weekStart in weekStarts)
        weekStart: statsProvider.getStatsForWeek(weekStart),
    };

    final orderedTags = <String>{...preferredTagIds};
    for (final stats in statsByWeek.values) {
      for (final entry in stats.sortedTagBreakdown.take(4)) {
        orderedTags.add(entry.key);
      }
    }

    return orderedTags.take(4).map((tagId) {
      final values = weekStarts
          .map((weekStart) => statsByWeek[weekStart]?.tagBreakdown[tagId] ?? 0)
          .toList();
      return _TagTrendSeries(tagId: tagId, minutesByWeek: values);
    }).toList();
  }

  void _showDailyDetailSheet(
    BuildContext context,
    DateTime date,
    int goalMinutesPerDay,
    List<SignalTask> tasks,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final totalActual = tasks.fold<int>(
          0,
          (sum, task) => sum + task.actualMinutes,
        );
        final totalEstimated = tasks.fold<int>(
          0,
          (sum, task) => sum + task.estimatedMinutes,
        );
        final completedTasks = tasks.where((task) => task.isComplete).length;
        final goalReached = totalActual >= goalMinutesPerDay;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _formatDayHeading(date),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Goal ${_formatMinutes(goalMinutesPerDay)} - ${goalReached ? 'hit' : 'not hit'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniDetailCard(
                        label: 'Actual',
                        value: _formatMinutes(totalActual),
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniDetailCard(
                        label: 'Estimated',
                        value: _formatMinutes(totalEstimated),
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniDetailCard(
                        label: 'Completed',
                        value: completedTasks.toString(),
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Session Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                if (tasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      color: Colors.grey.shade50,
                    ),
                    child: Text(
                      'No sessions logged for this day.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ...tasks.map((task) => _TaskSessionCard(task: task)),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportSummary(
    BuildContext context,
    WeeklyStats current,
    WeeklyStats previous,
    int goalMinutesPerDay,
    List<SignalTask> tasks,
  ) async {
    final planningData = _PlanningAccuracyData.fromTasks(tasks);
    final signalDelta =
        current.totalSignalMinutes - previous.totalSignalMinutes;
    final ratioDelta = current.signalPercentage - previous.signalPercentage;
    final avgDailyMinutes = (current.totalSignalMinutes / 7).round();
    final goalDelta = avgDailyMinutes - goalMinutesPerDay;

    final exportText = StringBuffer()
      ..writeln('Zen 80 Weekly Review - ${current.formattedDateRange}')
      ..writeln('')
      ..writeln(
        'Signal Time: ${current.formattedSignalTime} (${_formatDelta(signalDelta)})',
      )
      ..writeln(
        'Signal Ratio: ${current.signalPercentage.toStringAsFixed(0)}% (${_formatDelta(ratioDelta.round())} pts)',
      )
      ..writeln('Completed Tasks: ${current.completedTasksCount}')
      ..writeln(
        'Daily Goal Alignment: ${_formatMinutes(avgDailyMinutes)} avg vs ${_formatMinutes(goalMinutesPerDay)} target (${goalDelta >= 0 ? '+' : ''}${_formatMinutes(goalDelta.abs())})',
      )
      ..writeln(
        'Planning Accuracy: ${planningData.accuracyPercent.toStringAsFixed(0)}% (${_formatMinutes(planningData.totalEstimatedMinutes)} estimated, ${_formatMinutes(planningData.totalActualMinutes)} actual)',
      );

    await Clipboard.setData(ClipboardData(text: exportText.toString()));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weekly summary copied to clipboard')),
    );
  }

  String _formatDayHeading(DateTime date) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dayNames[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatDelta(int delta) {
    if (delta == 0) return '0m';
    return '${delta > 0 ? '+' : '-'}${_formatMinutes(delta.abs())}';
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }
}

class _HeroInsightsCard extends StatelessWidget {
  final WeeklyStats weeklyStats;
  final int averageDailySignalMinutes;
  final int goalMinutesPerDay;
  final double goalProgress;

  const _HeroInsightsCard({
    required this.weeklyStats,
    required this.averageDailySignalMinutes,
    required this.goalMinutesPerDay,
    required this.goalProgress,
  });

  @override
  Widget build(BuildContext context) {
    final reachedGoal = averageDailySignalMinutes >= goalMinutesPerDay;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Time Insight Snapshot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              if (weeklyStats.goldenRatioAchieved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '80%+ week',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              RatioRingChart(ratio: weeklyStats.signalNoiseRatio, size: 120),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily focus average',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMinutes(averageDailySignalMinutes)} / ${_formatMinutes(goalMinutesPerDay)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: goalProgress > 1 ? 1 : goalProgress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          reachedGoal
                              ? Colors.green.shade500
                              : Colors.blue.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reachedGoal
                          ? 'Goal aligned this week'
                          : 'Below goal by ${_formatMinutes(goalMinutesPerDay - averageDailySignalMinutes)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: reachedGoal
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

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
        borderRadius: BorderRadius.circular(14),
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

class _WeekComparisonCard extends StatelessWidget {
  final WeeklyStats currentWeek;
  final WeeklyStats previousWeek;

  const _WeekComparisonCard({
    required this.currentWeek,
    required this.previousWeek,
  });

  @override
  Widget build(BuildContext context) {
    final signalDelta =
        currentWeek.totalSignalMinutes - previousWeek.totalSignalMinutes;
    final completionDelta =
        currentWeek.completedTasksCount - previousWeek.completedTasksCount;
    final ratioDelta =
        currentWeek.signalPercentage - previousWeek.signalPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _ComparisonRow(
            label: 'Signal time',
            currentValue: _formatMinutes(currentWeek.totalSignalMinutes),
            previousValue: _formatMinutes(previousWeek.totalSignalMinutes),
            deltaText: _formatDelta(signalDelta),
          ),
          const SizedBox(height: 10),
          _ComparisonRow(
            label: 'Tasks completed',
            currentValue: '${currentWeek.completedTasksCount}',
            previousValue: '${previousWeek.completedTasksCount}',
            deltaText: completionDelta == 0
                ? '0'
                : '${completionDelta > 0 ? '+' : ''}$completionDelta',
          ),
          const SizedBox(height: 10),
          _ComparisonRow(
            label: 'Signal ratio',
            currentValue: '${currentWeek.signalPercentage.toStringAsFixed(0)}%',
            previousValue:
                '${previousWeek.signalPercentage.toStringAsFixed(0)}%',
            deltaText:
                '${ratioDelta >= 0 ? '+' : ''}${ratioDelta.toStringAsFixed(1)} pts',
          ),
        ],
      ),
    );
  }

  String _formatDelta(int value) {
    if (value == 0) return '0m';
    return '${value > 0 ? '+' : '-'}${_formatMinutes(value.abs())}';
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String currentValue;
  final String previousValue;
  final String deltaText;

  const _ComparisonRow({
    required this.label,
    required this.currentValue,
    required this.previousValue,
    required this.deltaText,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = deltaText.startsWith('+');
    final isNeutral =
        deltaText == '0' || deltaText == '0m' || deltaText.startsWith('+0');
    final deltaColor = isNeutral
        ? Colors.grey.shade600
        : isPositive
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          '$currentValue / $previousValue',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          deltaText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: deltaColor,
          ),
        ),
      ],
    );
  }
}

class _DailyInsightsChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  final int goalMinutesPerDay;
  final ValueChanged<DateTime> onDayTap;

  const _DailyInsightsChart({
    required this.dailyStats,
    required this.goalMinutesPerDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxMinutes = dailyStats.fold<int>(
      goalMinutesPerDay > 0 ? goalMinutesPerDay : 60,
      (max, stat) => stat.signalMinutes > max ? stat.signalMinutes : max,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyStats.map((stat) {
                const maxBarHeight = 110.0;
                final barHeight = maxMinutes > 0
                    ? (stat.signalMinutes / maxMinutes) * maxBarHeight
                    : 0.0;
                final reachedGoal = stat.signalMinutes >= goalMinutesPerDay;

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onDayTap(stat.date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatHours(stat.signalMinutes),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: barHeight.clamp(4.0, maxBarHeight),
                            decoration: BoxDecoration(
                              color: reachedGoal
                                  ? Colors.green.shade500
                                  : stat.signalMinutes > 0
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: reachedGoal
                                  ? Colors.green.shade600
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dayLabel(stat.date),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(color: Colors.green.shade500, label: 'Goal reached'),
              _LegendItem(color: Colors.blue.shade400, label: 'Signal minutes'),
              Text(
                'Tap a day for sessions',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatHours(int minutes) {
    if (minutes == 0) return '0h';
    return '${(minutes / 60).toStringAsFixed(1)}h';
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
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

class _PlanningAccuracyData {
  final int totalEstimatedMinutes;
  final int totalActualMinutes;
  final int trackedTasks;
  final int onTargetTasks;

  const _PlanningAccuracyData({
    required this.totalEstimatedMinutes,
    required this.totalActualMinutes,
    required this.trackedTasks,
    required this.onTargetTasks,
  });

  factory _PlanningAccuracyData.fromTasks(List<SignalTask> tasks) {
    final tracked = tasks.where((task) => task.estimatedMinutes > 0).toList();
    final totalEstimated = tracked.fold<int>(
      0,
      (sum, task) => sum + task.estimatedMinutes,
    );
    final totalActual = tracked.fold<int>(
      0,
      (sum, task) => sum + task.actualMinutes,
    );
    final onTarget = tracked.where((task) {
      if (task.actualMinutes == 0) return false;
      final delta = (task.actualMinutes - task.estimatedMinutes).abs();
      return delta <= 15;
    }).length;

    return _PlanningAccuracyData(
      totalEstimatedMinutes: totalEstimated,
      totalActualMinutes: totalActual,
      trackedTasks: tracked.length,
      onTargetTasks: onTarget,
    );
  }

  int get varianceMinutes => totalActualMinutes - totalEstimatedMinutes;

  double get accuracyPercent {
    if (totalEstimatedMinutes <= 0) return 0;
    final diff = (totalActualMinutes - totalEstimatedMinutes).abs();
    final score = (1 - (diff / totalEstimatedMinutes)).clamp(0.0, 1.0);
    return score * 100;
  }
}

class _PlanningAccuracyCard extends StatelessWidget {
  final _PlanningAccuracyData data;

  const _PlanningAccuracyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final varianceColor = data.varianceMinutes > 0
        ? Colors.red.shade700
        : data.varianceMinutes < 0
        ? Colors.green.shade700
        : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.accuracyPercent.toStringAsFixed(0)}% planning accuracy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (data.accuracyPercent / 100).clamp(0.0, 1.0),
            minHeight: 9,
            borderRadius: BorderRadius.circular(8),
            color: Colors.amber.shade600,
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated ${_formatMinutes(data.totalEstimatedMinutes)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              Expanded(
                child: Text(
                  'Actual ${_formatMinutes(data.totalActualMinutes)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Variance ${data.varianceMinutes >= 0 ? '+' : ''}${_formatMinutes(data.varianceMinutes.abs())}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: varianceColor,
                ),
              ),
              const Spacer(),
              Text(
                '${data.onTargetTasks}/${data.trackedTasks} tasks near estimate',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

class _TagTrendSeries {
  final String tagId;
  final List<int> minutesByWeek;

  const _TagTrendSeries({required this.tagId, required this.minutesByWeek});
}

class _TagTrendCard extends StatelessWidget {
  final List<_TagTrendSeries> series;
  final TagProvider tagProvider;

  const _TagTrendCard({required this.series, required this.tagProvider});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No tag trend data available yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final tagsMap = {for (final tag in tagProvider.tags) tag.id: tag};
    final maxValue = series
        .expand((s) => s.minutesByWeek)
        .fold<int>(1, (max, value) => value > max ? value : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: series.map((trend) {
          final tag = tagsMap[trend.tagId];
          final values = trend.minutesByWeek;
          final last = values.isNotEmpty ? values.last : 0;
          final previous = values.length > 1 ? values[values.length - 2] : 0;
          final delta = last - previous;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tag?.color ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag?.name ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: values.map((minutes) {
                      final barHeight = ((minutes / maxValue) * 32).clamp(
                        3.0,
                        32.0,
                      );
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: (tag?.color ?? Colors.grey).withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 62,
                  child: Text(
                    '${_formatMinutes(last)} ${delta == 0
                        ? ''
                        : delta > 0
                        ? '↑'
                        : '↓'}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: delta > 0
                          ? Colors.green.shade700
                          : delta < 0
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
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

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}

class _ExportCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _ExportCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.file_download_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Export weekly summary',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          TextButton(onPressed: onPressed, child: const Text('Copy')),
        ],
      ),
    );
  }
}

class _TagBreakdownChart extends StatelessWidget {
  final Map<String, int> tagMinutes;
  final Map<String, Tag> tags;

  const _TagBreakdownChart({required this.tagMinutes, required this.tags});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = tagMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalMinutes = sortedEntries.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
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
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tag?.color ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tag?.name ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatMinutes(minutes),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
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

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}

class _MiniDetailCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniDetailCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _TaskSessionCard extends StatelessWidget {
  final SignalTask task;

  const _TaskSessionCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final sortedSlots = [...task.timeSlots]
      ..sort((a, b) => a.plannedStartTime.compareTo(b.plannedStartTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated ${_formatMinutes(task.estimatedMinutes)} - Actual ${_formatMinutes(task.actualMinutes)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          if (sortedSlots.isEmpty)
            Text(
              'No sessions',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          else
            ...sortedSlots.map((slot) {
              final plannedStart = TimeOfDay.fromDateTime(
                slot.plannedStartTime,
              ).format(context);
              final plannedEnd = TimeOfDay.fromDateTime(
                slot.plannedEndTime,
              ).format(context);
              final actualDuration = slot.actualDuration.inMinutes;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$plannedStart - $plannedEnd',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatMinutes(slot.plannedDuration.inMinutes)} planned',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatMinutes(actualDuration)} actual',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}
