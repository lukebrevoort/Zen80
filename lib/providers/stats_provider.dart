import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

/// Helper class for daily statistics breakdown
class DailyStats {
  final DateTime date;
  final int signalMinutes;
  final int focusMinutes;
  final int completedTasks;

  const DailyStats({
    required this.date,
    required this.signalMinutes,
    required this.focusMinutes,
    required this.completedTasks,
  });

  /// Signal to focus ratio for the day (0.0 to 1.0)
  double get ratio =>
      focusMinutes > 0 ? (signalMinutes / focusMinutes).clamp(0.0, 1.0) : 0.0;

  /// Signal percentage (0 to 100)
  double get percentage => ratio * 100;

  /// Noise minutes for the day
  int get noiseMinutes {
    final noise = focusMinutes - signalMinutes;
    return noise > 0 ? noise : 0;
  }

  /// Whether the golden ratio (80%) was achieved for this day
  bool get goldenRatioAchieved => ratio >= 0.8;

  /// Check if this is a golden ratio day (>= 80%) - alias for goldenRatioAchieved
  bool get isGoldenRatio => ratio >= 0.8;

  /// Format signal time as readable string
  String get formattedSignalTime => _formatMinutes(signalMinutes);

  /// Format focus time as readable string
  String get formattedFocusTime => _formatMinutes(focusMinutes);

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

  /// Create empty stats for a date
  factory DailyStats.empty(DateTime date) {
    return DailyStats(
      date: date,
      signalMinutes: 0,
      focusMinutes: 0,
      completedTasks: 0,
    );
  }
}

/// Provider for calculating weekly statistics from SignalTask data
/// Used primarily by the Weekly Review screen
class StatsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final SettingsService _settingsService;

  /// Default focus hours per day (from QNA_GUIDE.md)
  static const int defaultFocusHoursPerDay = 16;

  StatsProvider(this._storageService, this._settingsService);

  // ============ Focus Hours Configuration ============

  /// Get focus hours per day from settings or default
  /// SettingsService doesn't have focusHoursPerDay yet, so default to 16
  int get focusHoursPerDay => defaultFocusHoursPerDay;

  /// Focus minutes per day
  int get focusMinutesPerDay => focusHoursPerDay * 60;

  /// Total focus minutes per week (7 days)
  int get focusMinutesPerWeek => focusMinutesPerDay * 7;

  // ============ Week Stats ============

  /// Get statistics for the current week
  WeeklyStats getCurrentWeekStats() {
    return getStatsForWeek(DateTime.now());
  }

  /// Get statistics for any week containing the given date
  WeeklyStats getStatsForWeek(DateTime anyDateInWeek) {
    final weekStart = WeeklyStats.getWeekStart(anyDateInWeek);
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Get all tasks for the week
    final weekTasks = _storageService.getSignalTasksForDateRange(
      weekStart,
      weekEnd,
    );

    // Calculate total signal minutes
    final totalSignalMinutes = _calculateTotalSignalMinutes(weekTasks);

    // Calculate focus minutes (based on settings)
    final totalFocusMinutes = focusMinutesPerWeek;

    // Calculate completed tasks count
    final completedTasksCount = weekTasks.where((t) => t.isComplete).length;

    // Calculate tag breakdown
    final tagBreakdown = calculateTagBreakdown(weekTasks);

    return WeeklyStats(
      weekStartDate: weekStart,
      totalSignalMinutes: totalSignalMinutes,
      totalFocusMinutes: totalFocusMinutes,
      completedTasksCount: completedTasksCount,
      tagBreakdown: tagBreakdown,
    );
  }

  /// Calculate total signal minutes from a list of tasks
  int _calculateTotalSignalMinutes(List<SignalTask> tasks) {
    return tasks.fold<int>(0, (sum, task) => sum + task.actualMinutes);
  }

  // ============ Tag Breakdown ============

  /// Calculate tag breakdown from tasks
  /// A task with multiple tags counts toward EACH tag
  Map<String, int> calculateTagBreakdown(List<SignalTask> tasks) {
    final tagMinutes = <String, int>{};

    for (final task in tasks) {
      final minutes = task.actualMinutes;
      if (minutes <= 0) continue;

      // Each tag gets the full actual minutes for this task
      for (final tagId in task.tagIds) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + minutes;
      }

      // If task has no tags, we could track as "untagged"
      // but for now we skip these as per requirements
    }

    return tagMinutes;
  }

  /// Get tag breakdown sorted by minutes (descending)
  List<MapEntry<String, int>> getSortedTagBreakdown(List<SignalTask> tasks) {
    final breakdown = calculateTagBreakdown(tasks);
    final entries = breakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // ============ Daily Breakdown ============

  /// Get daily breakdown for a week (7 days starting from weekStart)
  List<DailyStats> getDailyBreakdown(DateTime weekStart) {
    final normalizedStart = WeeklyStats.getWeekStart(weekStart);
    final dailyStats = <DailyStats>[];

    for (int i = 0; i < 7; i++) {
      final date = normalizedStart.add(Duration(days: i));
      final tasksForDay = _storageService.getSignalTasksForDate(date);

      final signalMinutes = tasksForDay.fold<int>(
        0,
        (sum, task) => sum + task.actualMinutes,
      );

      final completedTasks = tasksForDay.where((t) => t.isComplete).length;

      dailyStats.add(
        DailyStats(
          date: date,
          signalMinutes: signalMinutes,
          focusMinutes: focusMinutesPerDay,
          completedTasks: completedTasks,
        ),
      );
    }

    return dailyStats;
  }

  /// Get daily stats for a specific date
  DailyStats getDailyStats(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final tasksForDay = _storageService.getSignalTasksForDate(normalizedDate);

    final signalMinutes = tasksForDay.fold<int>(
      0,
      (sum, task) => sum + task.actualMinutes,
    );

    final completedTasks = tasksForDay.where((t) => t.isComplete).length;

    return DailyStats(
      date: normalizedDate,
      signalMinutes: signalMinutes,
      focusMinutes: focusMinutesPerDay,
      completedTasks: completedTasks,
    );
  }

  // ============ Week Navigation Helpers ============

  /// Get the Monday of the week containing the given date
  DateTime getWeekStart(DateTime date) {
    return WeeklyStats.getWeekStart(date);
  }

  /// Get the Sunday of the week containing the given date
  DateTime getWeekEnd(DateTime date) {
    return getWeekStart(date).add(const Duration(days: 6));
  }

  /// Get the previous week's start date
  DateTime getPreviousWeekStart(DateTime currentWeekStart) {
    return currentWeekStart.subtract(const Duration(days: 7));
  }

  /// Get the next week's start date
  DateTime getNextWeekStart(DateTime currentWeekStart) {
    return currentWeekStart.add(const Duration(days: 7));
  }

  /// Check if the given week is the current week
  bool isCurrentWeek(DateTime weekStart) {
    final currentWeekStart = getWeekStart(DateTime.now());
    return _isSameDay(weekStart, currentWeekStart);
  }

  // ============ Historical Stats ============

  /// Get stats for the last N weeks
  List<WeeklyStats> getStatsForLastWeeks(int numberOfWeeks) {
    final stats = <WeeklyStats>[];
    var weekStart = getWeekStart(DateTime.now());

    for (int i = 0; i < numberOfWeeks; i++) {
      stats.add(getStatsForWeek(weekStart));
      weekStart = getPreviousWeekStart(weekStart);
    }

    return stats;
  }

  /// Get average signal/noise ratio for the last N weeks
  double getAverageRatioForLastWeeks(int numberOfWeeks) {
    final stats = getStatsForLastWeeks(numberOfWeeks);
    if (stats.isEmpty) return 0.0;

    final totalRatio = stats.fold<double>(
      0,
      (sum, s) => sum + s.signalNoiseRatio,
    );
    return totalRatio / stats.length;
  }

  /// Get total signal minutes for the last N weeks
  int getTotalSignalMinutesForLastWeeks(int numberOfWeeks) {
    final stats = getStatsForLastWeeks(numberOfWeeks);
    return stats.fold<int>(0, (sum, s) => sum + s.totalSignalMinutes);
  }

  // ============ Persistence ============

  /// Save weekly stats to storage for caching/persistence
  Future<void> saveWeeklyStats(WeeklyStats stats) async {
    await _storageService.saveWeeklyStats(stats);
    notifyListeners();
  }

  /// Get cached weekly stats from storage
  WeeklyStats? getCachedWeeklyStats(DateTime weekStart) {
    return _storageService.getWeeklyStats(WeeklyStats.getWeekStart(weekStart));
  }

  /// Recalculate and save stats for a specific week
  Future<WeeklyStats> recalculateAndSaveWeekStats(DateTime weekStart) async {
    final stats = getStatsForWeek(weekStart);
    await saveWeeklyStats(stats);
    return stats;
  }

  /// Recalculate and save stats for the current week
  Future<WeeklyStats> recalculateCurrentWeekStats() async {
    return recalculateAndSaveWeekStats(DateTime.now());
  }

  // ============ Utility Methods ============

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Format a date range as readable string (e.g., "Jan 1 - 7" or "Dec 28 - Jan 3")
  String formatWeekRange(DateTime weekStart) {
    final weekEnd = getWeekEnd(weekStart);
    final stats = WeeklyStats(weekStartDate: weekStart);
    return stats.formattedDateRange;
  }

  /// Notify listeners of data changes
  /// Call this after tasks are updated to refresh stats
  void refresh() {
    notifyListeners();
  }
}
