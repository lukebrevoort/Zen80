import 'package:hive/hive.dart';

part 'day_schedule.g.dart';

/// Schedule settings for a specific day of the week
/// Allows users to set different active hours for each day
@HiveType(typeId: 13)
class DaySchedule {
  @HiveField(0)
  int dayOfWeek; // 1-7 (Monday = 1, Sunday = 7)

  @HiveField(1)
  int activeStartHour; // e.g., 7 for 7:00 AM

  @HiveField(2)
  int activeStartMinute; // e.g., 0 for 7:00 AM

  @HiveField(3)
  int activeEndHour; // e.g., 23 for 11:00 PM

  @HiveField(4)
  int activeEndMinute; // e.g., 0 for 11:00 PM

  @HiveField(5)
  bool isActiveDay; // Some users might not work on certain days

  DaySchedule({
    required this.dayOfWeek,
    this.activeStartHour = 8,
    this.activeStartMinute = 0,
    this.activeEndHour = 24,
    this.activeEndMinute = 0,
    this.isActiveDay = true,
  });

  /// Get the start time as a DateTime for a given date
  DateTime getStartTimeForDate(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      activeStartHour,
      activeStartMinute,
    );
  }

  /// Get the end time as a DateTime for a given date
  DateTime getEndTimeForDate(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      activeEndHour,
      activeEndMinute,
    );
  }

  /// Total active hours for this day
  double get activeHours {
    if (!isActiveDay) return 0;
    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;
    return (endMinutes - startMinutes) / 60.0;
  }

  /// Total active minutes for this day
  int get activeMinutes {
    if (!isActiveDay) return 0;
    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;
    return endMinutes - startMinutes;
  }

  /// Calculate elapsed active minutes from start time until now
  /// This is used for real-time signal ratio calculation
  /// Returns 0 if before start time, full activeMinutes if after end time
  int getElapsedMinutes(DateTime now) {
    if (!isActiveDay) return 0;

    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;
    final nowMinutes = now.hour * 60 + now.minute;

    // Before start time - no elapsed time yet
    if (nowMinutes < startMinutes) return 0;

    // After end time - return full active minutes
    if (nowMinutes >= endMinutes) return endMinutes - startMinutes;

    // During active hours - return elapsed since start
    return nowMinutes - startMinutes;
  }

  /// Get day name from dayOfWeek
  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// Get short day name
  String get shortDayName {
    switch (dayOfWeek) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '???';
    }
  }

  /// Format the active hours as a readable string
  String get formattedActiveHours {
    if (!isActiveDay) return 'Off';
    final startTime = _formatTime(activeStartHour, activeStartMinute);
    final endTime = _formatTime(activeEndHour, activeEndMinute);
    return '$startTime - $endTime';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Create a copy with optional overrides
  DaySchedule copyWith({
    int? dayOfWeek,
    int? activeStartHour,
    int? activeStartMinute,
    int? activeEndHour,
    int? activeEndMinute,
    bool? isActiveDay,
  }) {
    return DaySchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      activeStartHour: activeStartHour ?? this.activeStartHour,
      activeStartMinute: activeStartMinute ?? this.activeStartMinute,
      activeEndHour: activeEndHour ?? this.activeEndHour,
      activeEndMinute: activeEndMinute ?? this.activeEndMinute,
      isActiveDay: isActiveDay ?? this.isActiveDay,
    );
  }

  /// Create default schedule for all days (8 AM - 12 AM, 16 hours)
  static Map<int, DaySchedule> get defaultWeeklySchedule => {
    1: DaySchedule(dayOfWeek: 1), // Monday
    2: DaySchedule(dayOfWeek: 2), // Tuesday
    3: DaySchedule(dayOfWeek: 3), // Wednesday
    4: DaySchedule(dayOfWeek: 4), // Thursday
    5: DaySchedule(dayOfWeek: 5), // Friday
    6: DaySchedule(dayOfWeek: 6), // Saturday
    7: DaySchedule(dayOfWeek: 7), // Sunday
  };
}
