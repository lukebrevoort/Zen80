import 'package:hive/hive.dart';

part 'weekly_stats.g.dart';

/// Weekly statistics for tracking Signal vs Noise ratio and tag breakdown
@HiveType(typeId: 17)
class WeeklyStats extends HiveObject {
  @HiveField(0)
  DateTime weekStartDate; // Monday of that week

  @HiveField(1)
  int totalSignalMinutes;

  @HiveField(2)
  int totalFocusMinutes; // Sum of user's active hours for the week

  @HiveField(3)
  int completedTasksCount;

  @HiveField(4)
  Map<String, int> tagBreakdown; // tagId -> minutes

  WeeklyStats({
    required this.weekStartDate,
    this.totalSignalMinutes = 0,
    this.totalFocusMinutes = 0,
    this.completedTasksCount = 0,
    Map<String, int>? tagBreakdown,
  }) : tagBreakdown = tagBreakdown ?? {};

  /// Noise minutes = total focus time - signal time
  int get totalNoiseMinutes {
    final noise = totalFocusMinutes - totalSignalMinutes;
    return noise > 0 ? noise : 0;
  }

  /// Signal to Noise ratio (0.0 to 1.0)
  double get signalNoiseRatio {
    if (totalFocusMinutes <= 0) return 0;
    return (totalSignalMinutes / totalFocusMinutes).clamp(0.0, 1.0);
  }

  /// Signal percentage (0 to 100)
  double get signalPercentage => signalNoiseRatio * 100;

  /// Whether the golden ratio (80%) was achieved
  bool get goldenRatioAchieved => signalNoiseRatio >= 0.8;

  /// Format signal time as readable string
  String get formattedSignalTime => _formatMinutes(totalSignalMinutes);

  /// Format noise time as readable string
  String get formattedNoiseTime => _formatMinutes(totalNoiseMinutes);

  /// Format focus time as readable string
  String get formattedFocusTime => _formatMinutes(totalFocusMinutes);

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

  /// Add time to a tag's breakdown
  void addTimeToTag(String tagId, int minutes) {
    tagBreakdown[tagId] = (tagBreakdown[tagId] ?? 0) + minutes;
  }

  /// Get time for a specific tag
  int getTimeForTag(String tagId) {
    return tagBreakdown[tagId] ?? 0;
  }

  /// Get tags sorted by time spent (descending)
  List<MapEntry<String, int>> get sortedTagBreakdown {
    final entries = tagBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Week end date (Sunday)
  DateTime get weekEndDate => weekStartDate.add(const Duration(days: 6));

  /// Format date range as string
  String get formattedDateRange {
    final startMonth = _monthName(weekStartDate.month);
    final endMonth = _monthName(weekEndDate.month);

    if (startMonth == endMonth) {
      return '$startMonth ${weekStartDate.day} - ${weekEndDate.day}';
    } else {
      return '$startMonth ${weekStartDate.day} - $endMonth ${weekEndDate.day}';
    }
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  /// Create a copy with optional overrides
  WeeklyStats copyWith({
    DateTime? weekStartDate,
    int? totalSignalMinutes,
    int? totalFocusMinutes,
    int? completedTasksCount,
    Map<String, int>? tagBreakdown,
  }) {
    return WeeklyStats(
      weekStartDate: weekStartDate ?? this.weekStartDate,
      totalSignalMinutes: totalSignalMinutes ?? this.totalSignalMinutes,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      completedTasksCount: completedTasksCount ?? this.completedTasksCount,
      tagBreakdown: tagBreakdown ?? Map.from(this.tagBreakdown),
    );
  }

  /// Get the Monday of the week containing the given date
  static DateTime getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }
}
