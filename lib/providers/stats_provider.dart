import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

class StreakRefreshResult {
  final bool streakIncreased;
  final int currentStreak;

  const StreakRefreshResult({
    required this.streakIncreased,
    required this.currentStreak,
  });
}

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
  final Map<DateTime, _WeekComputation> _weekComputationCache = {};
  int? _cachedFocusHoursPerDay;

  /// Default focus hours per day (from QNA_GUIDE.md)
  static const int defaultFocusHoursPerDay = 8;
  static const double streakGoalThreshold = 0.8;

  StreakData _streakData = StreakData.initial();

  StatsProvider(this._storageService, this._settingsService) {
    _streakData = _storageService.getStreakData();
  }

  StreakData get streakData => _streakData;

  bool get hasRecoverableMissedDay {
    final pendingDate = _streakData.pendingMissedDate;
    if (pendingDate == null) return false;
    final yesterday = _normalizeDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    return _isSameDay(pendingDate, yesterday);
  }

  bool get canUseStreakFreeze {
    return hasRecoverableMissedDay && _streakData.availableFreezes > 0;
  }

  bool get canRecoverStreak {
    return hasRecoverableMissedDay;
  }

  Future<StreakRefreshResult> refreshStreak({DateTime? now}) async {
    final today = _normalizeDate(now ?? DateTime.now());
    final previousStreak = _streakData.currentStreak;
    var updated = _streakData;

    if (updated.pendingMissedDate != null &&
        today.difference(updated.pendingMissedDate!).inDays > 1) {
      updated = updated.copyWith(
        clearPendingMissedDate: true,
        pendingStreakBase: 0,
      );
    }

    DateTime? startDate;
    if (updated.lastProcessedDate == null) {
      final allTasks = _storageService.getAllSignalTasks();
      if (allTasks.isEmpty) {
        updated = updated.copyWith(lastProcessedDate: today);
        await _persistStreakData(updated);
        return StreakRefreshResult(
          streakIncreased: false,
          currentStreak: updated.currentStreak,
        );
      }

      final earliestDate = allTasks
          .map((task) => _normalizeDate(task.scheduledDate))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      startDate = earliestDate;
    } else {
      startDate = _normalizeDate(
        updated.lastProcessedDate!.add(const Duration(days: 1)),
      );
    }

    if (startDate.isAfter(today)) {
      return StreakRefreshResult(
        streakIncreased: false,
        currentStreak: updated.currentStreak,
      );
    }

    DateTime cursor = startDate;
    while (!cursor.isAfter(today)) {
      final achieved = _isGoalAchievedForDate(cursor);

      if (achieved) {
        if (updated.lastGoalDate != null &&
            _isSameDay(updated.lastGoalDate!, cursor)) {
          // Day already counted.
        } else if (updated.lastGoalDate != null &&
            _isSameDay(
              updated.lastGoalDate!.add(const Duration(days: 1)),
              cursor,
            )) {
          updated = updated.copyWith(
            currentStreak: updated.currentStreak + 1,
            lastGoalDate: cursor,
          );
        } else {
          updated = updated.copyWith(currentStreak: 1, lastGoalDate: cursor);
        }

        if (updated.currentStreak > updated.longestStreak) {
          updated = updated.copyWith(longestStreak: updated.currentStreak);
        }
      } else {
        if (updated.currentStreak > 0 && updated.pendingMissedDate == null) {
          updated = updated.copyWith(
            pendingMissedDate: cursor,
            pendingStreakBase: updated.currentStreak,
          );
        }
        updated = updated.copyWith(currentStreak: 0);
      }

      updated = updated.copyWith(lastProcessedDate: cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    await _persistStreakData(updated);

    return StreakRefreshResult(
      streakIncreased: updated.currentStreak > previousStreak,
      currentStreak: updated.currentStreak,
    );
  }

  Future<void> useStreakFreeze() async {
    if (!canUseStreakFreeze) return;

    final pendingDate = _streakData.pendingMissedDate;
    if (pendingDate == null) return;

    final restoredStreak =
        _streakData.pendingStreakBase + _streakData.currentStreak;
    final restoredLastGoalDate =
        (_streakData.lastGoalDate != null &&
            _streakData.lastGoalDate!.isAfter(pendingDate))
        ? _streakData.lastGoalDate
        : pendingDate;

    await _persistStreakData(
      _streakData.copyWith(
        currentStreak: restoredStreak,
        longestStreak: math.max(_streakData.longestStreak, restoredStreak),
        availableFreezes: _streakData.availableFreezes - 1,
        lastGoalDate: restoredLastGoalDate,
        clearPendingMissedDate: true,
        pendingStreakBase: 0,
      ),
    );
  }

  Future<void> recoverStreak() async {
    if (!canRecoverStreak) return;

    final pendingDate = _streakData.pendingMissedDate;
    if (pendingDate == null) return;

    final restoredStreak =
        _streakData.pendingStreakBase + _streakData.currentStreak;
    final restoredLastGoalDate =
        (_streakData.lastGoalDate != null &&
            _streakData.lastGoalDate!.isAfter(pendingDate))
        ? _streakData.lastGoalDate
        : pendingDate;

    await _persistStreakData(
      _streakData.copyWith(
        currentStreak: restoredStreak,
        longestStreak: math.max(_streakData.longestStreak, restoredStreak),
        lastGoalDate: restoredLastGoalDate,
        clearPendingMissedDate: true,
        pendingStreakBase: 0,
      ),
    );
  }

  // ============ Focus Hours Configuration ============

  /// Get focus hours per day from settings or default
  int get focusHoursPerDay {
    final settings = _storageService.getUserSettings();
    final hours = settings.focusHoursPerDay;
    if (hours <= 0) return defaultFocusHoursPerDay;
    return hours;
  }

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
    return _getWeekComputation(anyDateInWeek).weeklyStats;
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
    return _getWeekComputation(weekStart).dailyBreakdown;
  }

  /// Get all signal tasks for a specific week (Monday-Sunday)
  List<SignalTask> getTasksForWeek(DateTime weekStart) {
    return _getWeekComputation(weekStart).weekTasks;
  }

  /// Get all signal tasks for a specific day
  List<SignalTask> getTasksForDay(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final weekStart = WeeklyStats.getWeekStart(normalizedDate);
    final cachedWeek = _weekComputationCache[weekStart];
    if (cachedWeek != null) {
      return cachedWeek.getTasksForDay(normalizedDate);
    }
    return _storageService.getSignalTasksForDate(normalizedDate);
  }

  /// Get all signal tasks for a specific week (Monday-Sunday)
  List<SignalTask> getTasksForWeek(DateTime weekStart) {
    final normalizedStart = WeeklyStats.getWeekStart(weekStart);
    final weekEnd = normalizedStart.add(const Duration(days: 6));
    return _storageService.getSignalTasksForDateRange(normalizedStart, weekEnd);
  }

  /// Get all signal tasks for a specific day
  List<SignalTask> getTasksForDay(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _storageService.getSignalTasksForDate(normalizedDate);
  }

  /// Get daily stats for a specific date
  DailyStats getDailyStats(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final weekStart = WeeklyStats.getWeekStart(normalizedDate);
    final cachedWeek = _weekComputationCache[weekStart];
    if (cachedWeek != null) {
      return cachedWeek.getDailyStats(normalizedDate);
    }
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
    final stats = WeeklyStats(weekStartDate: weekStart);
    return stats.formattedDateRange;
  }

  /// Notify listeners of data changes
  /// Call this after tasks are updated to refresh stats
  void refresh() {
    _invalidateWeekCache();
    notifyListeners();
  }

  bool _isGoalAchievedForDate(DateTime date) {
    final daily = getDailyStats(date);
    return daily.ratio >= streakGoalThreshold;
  _WeekComputation _getWeekComputation(DateTime anyDateInWeek) {
    _syncCacheWithFocusHours();

    final weekStart = WeeklyStats.getWeekStart(anyDateInWeek);
    final cached = _weekComputationCache[weekStart];
    if (cached != null) {
      return cached;
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekTasks = _storageService.getSignalTasksForDateRange(
      weekStart,
      weekEnd,
    );

    final tasksByDay = <DateTime, List<SignalTask>>{
      for (int i = 0; i < 7; i++) weekStart.add(Duration(days: i)): [],
    };

    for (final task in weekTasks) {
      final taskDate = _normalizeDate(task.scheduledDate);
      final bucket = tasksByDay[taskDate];
      if (bucket != null) {
        bucket.add(task);
      }
    }

    final dailyBreakdown = List<DailyStats>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final tasksForDay = tasksByDay[date] ?? const <SignalTask>[];
      final signalMinutes = _calculateTotalSignalMinutes(tasksForDay);
      final completedTasks = tasksForDay
          .where((task) => task.isComplete)
          .length;

      return DailyStats(
        date: date,
        signalMinutes: signalMinutes,
        focusMinutes: focusMinutesPerDay,
        completedTasks: completedTasks,
      );
    });

    final weekStats = WeeklyStats(
      weekStartDate: weekStart,
      totalSignalMinutes: _calculateTotalSignalMinutes(weekTasks),
      totalFocusMinutes: focusMinutesPerWeek,
      completedTasksCount: weekTasks.where((t) => t.isComplete).length,
      tagBreakdown: calculateTagBreakdown(weekTasks),
    );

    final computation = _WeekComputation(
      weekTasks: weekTasks,
      tasksByDay: tasksByDay,
      dailyBreakdown: dailyBreakdown,
      weeklyStats: weekStats,
    );

    _weekComputationCache[weekStart] = computation;
    return computation;
  }

  void _syncCacheWithFocusHours() {
    final currentFocusHours = focusHoursPerDay;
    if (_cachedFocusHoursPerDay != null &&
        _cachedFocusHoursPerDay != currentFocusHours) {
      _invalidateWeekCache();
    }
    _cachedFocusHoursPerDay = currentFocusHours;
  }

  void _invalidateWeekCache() {
    _weekComputationCache.clear();
    _cachedFocusHoursPerDay = null;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _persistStreakData(StreakData value) async {
    _streakData = value;
    await _storageService.saveStreakData(value);
    notifyListeners();
}

class _WeekComputation {
  final List<SignalTask> weekTasks;
  final Map<DateTime, List<SignalTask>> _tasksByDay;
  final List<DailyStats> dailyBreakdown;
  final WeeklyStats weeklyStats;

  _WeekComputation({
    required List<SignalTask> weekTasks,
    required Map<DateTime, List<SignalTask>> tasksByDay,
    required List<DailyStats> dailyBreakdown,
    required this.weeklyStats,
  }) : weekTasks = List<SignalTask>.unmodifiable(weekTasks),
       _tasksByDay = {
         for (final entry in tasksByDay.entries)
           entry.key: List<SignalTask>.unmodifiable(entry.value),
       },
       dailyBreakdown = List<DailyStats>.unmodifiable(dailyBreakdown);

  List<SignalTask> getTasksForDay(DateTime date) {
    return List<SignalTask>.from(_tasksByDay[date] ?? const <SignalTask>[]);
  }

  DailyStats getDailyStats(DateTime date) {
    final stats = dailyBreakdown.firstWhere(
      (dayStats) =>
          dayStats.date.year == date.year &&
          dayStats.date.month == date.month &&
          dayStats.date.day == date.day,
      orElse: () => DailyStats.empty(date),
    );
    return stats;
  }
}
