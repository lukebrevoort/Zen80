import 'package:hive/hive.dart';
import 'day_schedule.dart';

part 'user_settings.g.dart';

/// User preferences and settings
/// Includes active hours per day, notification preferences, and Google Calendar tokens
@HiveType(typeId: 16)
class UserSettings extends HiveObject {
  @HiveField(0)
  Map<int, DaySchedule> weeklySchedule; // 1=Mon, 7=Sun -> DaySchedule

  @HiveField(1)
  bool autoStartTasks; // Automatically start tasks at scheduled time

  @HiveField(2)
  bool autoEndTasks; // Automatically end tasks at scheduled end time

  @HiveField(3)
  int notificationBeforeEndMinutes; // Minutes before task ends to notify

  @HiveField(4)
  bool hasCompletedOnboarding;

  @HiveField(5)
  String defaultSignalColorHex; // Default color for signal events in calendar

  @HiveField(6)
  int notificationBeforeStartMinutes; // Minutes before task starts to notify

  @HiveField(7)
  bool showRolloverSuggestions; // Show suggestions for incomplete tasks

  @HiveField(8)
  int dataVersion; // For migration tracking

  UserSettings({
    Map<int, DaySchedule>? weeklySchedule,
    this.autoStartTasks = false,
    this.autoEndTasks = true,
    this.notificationBeforeEndMinutes = 5,
    this.hasCompletedOnboarding = false,
    this.defaultSignalColorHex = '#000000', // Black as default signal color
    this.notificationBeforeStartMinutes = 5,
    this.showRolloverSuggestions = true,
    this.dataVersion = 2, // v2 for new data model
  }) : weeklySchedule = weeklySchedule ?? DaySchedule.defaultWeeklySchedule;

  /// Get the schedule for a specific day
  DaySchedule getScheduleForDay(int dayOfWeek) {
    return weeklySchedule[dayOfWeek] ?? DaySchedule(dayOfWeek: dayOfWeek);
  }

  /// Get the schedule for today
  DaySchedule get todaySchedule {
    final today = DateTime.now().weekday;
    return getScheduleForDay(today);
  }

  /// Update the schedule for a specific day
  void updateDaySchedule(int dayOfWeek, DaySchedule schedule) {
    weeklySchedule[dayOfWeek] = schedule;
  }

  /// Total active hours per week
  double get totalWeeklyActiveHours {
    return weeklySchedule.values.fold<double>(
      0,
      (sum, schedule) => sum + schedule.activeHours,
    );
  }

  /// Total active minutes per week
  int get totalWeeklyActiveMinutes {
    return weeklySchedule.values.fold<int>(
      0,
      (sum, schedule) => sum + schedule.activeMinutes,
    );
  }

  /// Check if a given time is within active hours for its day
  bool isWithinActiveHours(DateTime dateTime) {
    final schedule = getScheduleForDay(dateTime.weekday);
    if (!schedule.isActiveDay) return false;

    final startTime = schedule.getStartTimeForDate(dateTime);
    final endTime = schedule.getEndTimeForDate(dateTime);

    return dateTime.isAfter(startTime) && dateTime.isBefore(endTime);
  }

  /// Create default settings
  static UserSettings get defaults => UserSettings();

  /// Create a copy with optional overrides
  UserSettings copyWith({
    Map<int, DaySchedule>? weeklySchedule,
    bool? autoStartTasks,
    bool? autoEndTasks,
    int? notificationBeforeEndMinutes,
    bool? hasCompletedOnboarding,
    String? defaultSignalColorHex,
    int? notificationBeforeStartMinutes,
    bool? showRolloverSuggestions,
    int? dataVersion,
  }) {
    return UserSettings(
      weeklySchedule: weeklySchedule ?? Map.from(this.weeklySchedule),
      autoStartTasks: autoStartTasks ?? this.autoStartTasks,
      autoEndTasks: autoEndTasks ?? this.autoEndTasks,
      notificationBeforeEndMinutes:
          notificationBeforeEndMinutes ?? this.notificationBeforeEndMinutes,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      defaultSignalColorHex:
          defaultSignalColorHex ?? this.defaultSignalColorHex,
      notificationBeforeStartMinutes:
          notificationBeforeStartMinutes ?? this.notificationBeforeStartMinutes,
      showRolloverSuggestions:
          showRolloverSuggestions ?? this.showRolloverSuggestions,
      dataVersion: dataVersion ?? this.dataVersion,
    );
  }
}
