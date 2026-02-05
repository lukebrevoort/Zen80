import 'package:hive/hive.dart';

part 'day_schedule.g.dart';

/// Schedule settings for a specific day of the week
/// Allows users to set different active hours for each day
///
/// CROSS-MIDNIGHT SUPPORT:
/// Users can set end times that extend into the next calendar day.
/// For example, a college student might set 10 AM - 2 AM (next day).
///
/// Rules:
/// - If endHour < startHour, the end time is on the NEXT calendar day
/// - The end time cannot go past the start time (no 24+ hour schedules)
/// - Valid: 12 PM → 2 AM (next day) = 14 hours
/// - Valid: 10 AM → 3 AM (next day) = 17 hours
/// - Invalid: 8 AM → 9 AM (next day) = 25 hours (wraps past start)
///
/// The [crossesMidnight] getter indicates if the schedule extends to the next day.
@HiveType(typeId: 13)
class DaySchedule {
  @HiveField(0)
  int dayOfWeek; // 1-7 (Monday = 1, Sunday = 7)

  @HiveField(1)
  int activeStartHour; // e.g., 7 for 7:00 AM

  @HiveField(2)
  int activeStartMinute; // e.g., 0 for 7:00 AM

  @HiveField(3)
  int activeEndHour; // e.g., 23 for 11:00 PM, or 2 for 2:00 AM next day

  @HiveField(4)
  int activeEndMinute; // e.g., 0 for 11:00 PM

  @HiveField(5)
  bool isActiveDay; // Some users might not work on certain days

  DaySchedule({
    required this.dayOfWeek,
    this.activeStartHour = 0,
    this.activeStartMinute = 0,
    this.activeEndHour = 23,
    this.activeEndMinute = 59,
    this.isActiveDay = true,
  });

  /// Whether this schedule extends past midnight into the next calendar day
  /// True if end time is "earlier" than start time (e.g., 10 AM → 2 AM)
  bool get crossesMidnight {
    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;
    return endMinutes < startMinutes;
  }

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
  /// If the schedule crosses midnight, returns the NEXT day's end time
  DateTime getEndTimeForDate(DateTime date) {
    final baseDate = crossesMidnight ? date.add(const Duration(days: 1)) : date;
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      activeEndHour,
      activeEndMinute,
    );
  }

  /// Total active hours for this day (handles cross-midnight)
  double get activeHours {
    if (!isActiveDay) return 0;
    return activeMinutes / 60.0;
  }

  /// Total active minutes for this day (handles cross-midnight)
  /// For cross-midnight schedules: minutes from start to midnight + midnight to end
  int get activeMinutes {
    if (!isActiveDay) return 0;

    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;

    if (crossesMidnight) {
      // e.g., 10 AM (600) → 2 AM (120)
      // Minutes until midnight: 1440 - 600 = 840
      // Minutes after midnight: 120
      // Total: 840 + 120 = 960 (16 hours)
      const minutesInDay = 24 * 60; // 1440
      return (minutesInDay - startMinutes) + endMinutes;
    } else {
      return endMinutes - startMinutes;
    }
  }

  /// Calculate elapsed active minutes from start time until now
  /// This is used for real-time signal ratio calculation
  /// Returns 0 if before start time, full activeMinutes if after end time
  ///
  /// For cross-midnight schedules:
  /// - If now is after start time (same day): elapsed = now - start
  /// - If now is before end time (next day morning): elapsed = (midnight - start) + now
  /// - If now is after end time (next day): elapsed = full activeMinutes
  int getElapsedMinutes(DateTime now) {
    if (!isActiveDay) return 0;

    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;
    final nowMinutes = now.hour * 60 + now.minute;
    const minutesInDay = 24 * 60; // 1440

    if (crossesMidnight) {
      // Schedule like 10 AM → 2 AM
      // Three possible states:
      // 1. Before start time (same day morning): not started yet
      // 2. After start time (same day): in progress
      // 3. After midnight but before end: still in progress from yesterday
      // 4. After end time (next day): completed

      if (nowMinutes >= startMinutes) {
        // Case 2: After start time on the same day (e.g., it's 3 PM)
        return nowMinutes - startMinutes;
      } else if (nowMinutes < endMinutes) {
        // Case 3: After midnight, before end time (e.g., it's 1 AM)
        // We're in the "next day" portion of yesterday's schedule
        return (minutesInDay - startMinutes) + nowMinutes;
      } else if (nowMinutes >= endMinutes && nowMinutes < startMinutes) {
        // Case 1 & 4: Between end time and start time (e.g., it's 8 AM)
        // This is the "gap" period - schedule is complete from yesterday
        return activeMinutes;
      }
      return 0;
    } else {
      // Normal same-day schedule (e.g., 8 AM → 5 PM)
      if (nowMinutes < startMinutes) return 0;
      if (nowMinutes >= endMinutes) return activeMinutes;
      return nowMinutes - startMinutes;
    }
  }

  /// Check if a given time falls within this schedule's active hours
  /// Handles cross-midnight schedules correctly
  bool isTimeWithinActiveHours(DateTime time) {
    if (!isActiveDay) return false;

    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = activeStartHour * 60 + activeStartMinute;
    final endMinutes = activeEndHour * 60 + activeEndMinute;

    if (crossesMidnight) {
      // Active if: after start (same day) OR before end (next day morning)
      return timeMinutes >= startMinutes || timeMinutes < endMinutes;
    } else {
      return timeMinutes >= startMinutes && timeMinutes < endMinutes;
    }
  }

  /// Validate that this schedule is valid
  /// Returns null if valid, or an error message if invalid
  String? validate() {
    if (activeStartHour < 0 || activeStartHour > 23) {
      return 'Start hour must be between 0 and 23';
    }
    if (activeEndHour < 0 || activeEndHour > 23) {
      return 'End hour must be between 0 and 23';
    }
    if (activeStartMinute < 0 || activeStartMinute > 59) {
      return 'Start minute must be between 0 and 59';
    }
    if (activeEndMinute < 0 || activeEndMinute > 59) {
      return 'End minute must be between 0 and 59';
    }

    // Check that schedule doesn't exceed ~23 hours
    // (End time can't go past start time of next cycle)
    if (activeMinutes > 23 * 60) {
      return 'Focus time cannot exceed 23 hours';
    }

    if (activeMinutes < 30) {
      return 'Focus time must be at least 30 minutes';
    }

    return null; // Valid
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
  /// Shows "(next day)" indicator for cross-midnight schedules
  String get formattedActiveHours {
    if (!isActiveDay) return 'Off';
    final startTime = _formatTime(activeStartHour, activeStartMinute);
    final endTime = _formatTime(activeEndHour, activeEndMinute);
    if (crossesMidnight) {
      return '$startTime - $endTime +1';
    }
    return '$startTime - $endTime';
  }

  /// Format just the start time
  String get formattedStartTime {
    return _formatTime(activeStartHour, activeStartMinute);
  }

  /// Format just the end time
  String get formattedEndTime {
    return _formatTime(activeEndHour, activeEndMinute);
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
