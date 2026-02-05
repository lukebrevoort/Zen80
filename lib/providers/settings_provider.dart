import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

/// Provider for managing user settings
class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  UserSettings _settings = UserSettings.defaults;

  /// Ephemeral per-day effective start time overrides.
  /// When a user starts a task before their scheduled focus time,
  /// we extend the focus window for that day to include the early start.
  /// Key: date string (yyyy-MM-dd), Value: effective start hour (0-23)
  /// Also stores minute for precision: hour * 60 + minute
  final Map<String, int> _dailyEffectiveStartMinutes = {};

  /// Whether the user has seen the early start education dialog
  bool _hasSeenEarlyStartEducation = false;

  SettingsProvider(this._storageService) {
    _loadSettings();
    _loadEarlyStartEducationFlag();
  }

  /// Load the early start education flag from storage
  Future<void> _loadEarlyStartEducationFlag() async {
    _hasSeenEarlyStartEducation =
        _storageService.getBool('hasSeenEarlyStartEducation') ?? false;
  }

  /// Whether the user has seen the early start education
  bool get hasSeenEarlyStartEducation => _hasSeenEarlyStartEducation;

  /// Mark that the user has seen the early start education
  Future<void> markEarlyStartEducationSeen() async {
    _hasSeenEarlyStartEducation = true;
    await _storageService.setBool('hasSeenEarlyStartEducation', true);
    notifyListeners();
  }

  /// Current user settings
  UserSettings get settings => _settings;

  /// Whether onboarding has been completed
  bool get hasCompletedOnboarding => _settings.hasCompletedOnboarding;

  /// Whether schedule setup has been completed
  bool get hasCompletedScheduleSetup => _settings.hasCompletedScheduleSetup;

  /// Whether auto-start is enabled
  bool get autoStartTasks => _settings.autoStartTasks;

  /// Whether auto-end is enabled
  bool get autoEndTasks => _settings.autoEndTasks;

  /// Minutes before task end to notify
  int get notificationBeforeEndMinutes =>
      _settings.notificationBeforeEndMinutes;

  /// Minutes before task start to notify
  int get notificationBeforeStartMinutes =>
      _settings.notificationBeforeStartMinutes;

  /// Default signal color for calendar events
  String get defaultSignalColorHex => _settings.defaultSignalColorHex;

  /// Whether to show rollover suggestions
  bool get showRolloverSuggestions => _settings.showRolloverSuggestions;

  /// Whether start reminders are enabled
  bool get enableStartReminders => _settings.enableStartReminders;

  /// Whether end reminders are enabled
  bool get enableEndReminders => _settings.enableEndReminders;

  /// Whether next task reminders are enabled
  bool get enableNextTaskReminders => _settings.enableNextTaskReminders;

  /// Target focus hours per day
  int get focusHoursPerDay => _settings.focusHoursPerDay;

  /// Target focus minutes per day
  int get focusMinutesPerDay => _settings.focusHoursPerDay * 60;

  /// Today's schedule
  DaySchedule get todaySchedule => _settings.todaySchedule;

  /// Weekly schedule map
  Map<int, DaySchedule> get weeklySchedule => _settings.weeklySchedule;

  /// User's timezone (null means use device default)
  String? get timezone => _settings.timezone;

  /// Effective timezone (user's setting or device default)
  String get effectiveTimezone => _settings.effectiveTimezone;

  // ============ Effective Focus Time (Early Start Support) ============

  /// Get the date key for a DateTime (yyyy-MM-dd)
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get the effective start time for a given date.
  /// Returns the earlier of: configured focus start OR earliest task start that day.
  /// Returns null if no override exists (use configured schedule).
  DateTime? getEffectiveStartTime(DateTime date) {
    final key = _dateKey(date);
    final overrideMinutes = _dailyEffectiveStartMinutes[key];
    if (overrideMinutes == null) return null;

    final hour = overrideMinutes ~/ 60;
    final minute = overrideMinutes % 60;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Get the effective start hour for today (for calendar display).
  /// Returns the configured start hour OR the override if user started early.
  int getEffectiveStartHourForDate(DateTime date) {
    final override = getEffectiveStartTime(date);
    if (override != null) {
      return override.hour;
    }
    final schedule = _settings.getScheduleForDay(date.weekday);
    return schedule.activeStartHour;
  }

  /// Get today's effective start hour
  int get todayEffectiveStartHour {
    return getEffectiveStartHourForDate(DateTime.now());
  }

  /// Check if a time is before the configured focus start time for that day
  bool isBeforeFocusTime(DateTime time) {
    final schedule = _settings.getScheduleForDay(time.weekday);
    final focusStart = DateTime(
      time.year,
      time.month,
      time.day,
      schedule.activeStartHour,
      schedule.activeStartMinute,
    );
    return time.isBefore(focusStart);
  }

  /// Extend focus time for a specific date to include an earlier start.
  /// Called when user starts a task before their configured focus time.
  /// Returns true if this is the first early start today (for nudge display).
  bool extendFocusTimeForDate(DateTime date, DateTime startTime) {
    final schedule = _settings.getScheduleForDay(date.weekday);
    final key = _dateKey(date);

    // Check if we're actually before focus time
    final focusStart = DateTime(
      date.year,
      date.month,
      date.day,
      schedule.activeStartHour,
      schedule.activeStartMinute,
    );

    if (!startTime.isBefore(focusStart)) {
      return false; // Not an early start
    }

    // Check if we already have an override for today
    final existingOverride = _dailyEffectiveStartMinutes[key];
    final newMinutes = startTime.hour * 60 + startTime.minute;

    // Only update if this is earlier than any existing override
    if (existingOverride == null || newMinutes < existingOverride) {
      _dailyEffectiveStartMinutes[key] = newMinutes;
      notifyListeners();

      // Return true if this is the first override today (for showing nudge)
      return existingOverride == null;
    }

    return false;
  }

  /// Clear the effective start time override for a date.
  /// Called if user manually adjusts their schedule.
  void clearEffectiveStartOverride(DateTime date) {
    final key = _dateKey(date);
    if (_dailyEffectiveStartMinutes.containsKey(key)) {
      _dailyEffectiveStartMinutes.remove(key);
      notifyListeners();
    }
  }

  /// Check if today has an effective start time override (user started early)
  bool get hasEarlyStartToday {
    final key = _dateKey(DateTime.now());
    return _dailyEffectiveStartMinutes.containsKey(key);
  }

  /// Get the formatted effective start time for today (for display)
  String? get formattedEffectiveStartToday {
    final effectiveStart = getEffectiveStartTime(DateTime.now());
    if (effectiveStart == null) return null;

    final hour = effectiveStart.hour;
    final minute = effectiveStart.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    _settings = _storageService.getUserSettings();
    notifyListeners();
  }

  /// Refresh settings from storage
  Future<void> refresh() async {
    await _loadSettings();
  }

  /// Save current settings
  Future<void> _saveSettings() async {
    await _storageService.saveUserSettings(_settings);
    notifyListeners();
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    _settings = _settings.copyWith(hasCompletedOnboarding: true);
    await _saveSettings();
  }

  /// Mark schedule setup as completed
  Future<void> completeScheduleSetup() async {
    _settings = _settings.copyWith(hasCompletedScheduleSetup: true);
    await _saveSettings();
  }

  /// Set the user's timezone
  /// Pass null to use device default
  Future<void> setTimezone(String? timezone) async {
    _settings = _settings.copyWith(timezone: timezone);
    await _saveSettings();
  }

  /// Auto-detect and set timezone from Google Calendar
  /// Called after Google Calendar authentication
  Future<void> setTimezoneFromCalendar(String calendarTimezone) async {
    _settings = _settings.copyWith(timezone: calendarTimezone);
    await _saveSettings();
  }

  /// Update auto-start setting
  Future<void> setAutoStartTasks(bool value) async {
    _settings = _settings.copyWith(autoStartTasks: value);
    await _saveSettings();
  }

  /// Update auto-end setting
  Future<void> setAutoEndTasks(bool value) async {
    _settings = _settings.copyWith(autoEndTasks: value);
    await _saveSettings();
  }

  /// Update notification before end minutes
  Future<void> setNotificationBeforeEndMinutes(int minutes) async {
    _settings = _settings.copyWith(notificationBeforeEndMinutes: minutes);
    await _saveSettings();
  }

  /// Update notification before start minutes
  Future<void> setNotificationBeforeStartMinutes(int minutes) async {
    _settings = _settings.copyWith(notificationBeforeStartMinutes: minutes);
    await _saveSettings();
  }

  /// Update default signal color
  Future<void> setDefaultSignalColor(String colorHex) async {
    _settings = _settings.copyWith(defaultSignalColorHex: colorHex);
    await _saveSettings();
  }

  /// Update rollover suggestions setting
  Future<void> setShowRolloverSuggestions(bool value) async {
    _settings = _settings.copyWith(showRolloverSuggestions: value);
    await _saveSettings();
  }

  /// Update start reminders setting
  Future<void> setEnableStartReminders(bool value) async {
    _settings = _settings.copyWith(enableStartReminders: value);
    await _saveSettings();
  }

  /// Update end reminders setting
  Future<void> setEnableEndReminders(bool value) async {
    _settings = _settings.copyWith(enableEndReminders: value);
    await _saveSettings();
  }

  /// Update next task reminders setting
  Future<void> setEnableNextTaskReminders(bool value) async {
    _settings = _settings.copyWith(enableNextTaskReminders: value);
    await _saveSettings();
  }

  /// Update focus hours per day
  Future<void> setFocusHoursPerDay(int hours) async {
    final clamped = hours.clamp(1, 12);
    _settings = _settings.copyWith(focusHoursPerDay: clamped);
    await _saveSettings();
  }

  /// Update schedule for a specific day
  Future<void> updateDaySchedule(int dayOfWeek, DaySchedule schedule) async {
    final newSchedule = Map<int, DaySchedule>.from(_settings.weeklySchedule);
    newSchedule[dayOfWeek] = schedule;
    _settings = _settings.copyWith(weeklySchedule: newSchedule);
    await _saveSettings();
  }

  /// Update entire weekly schedule
  Future<void> updateWeeklySchedule(Map<int, DaySchedule> schedule) async {
    _settings = _settings.copyWith(weeklySchedule: schedule);
    await _saveSettings();
  }

  /// Get schedule for a specific day
  DaySchedule getScheduleForDay(int dayOfWeek) {
    return _settings.getScheduleForDay(dayOfWeek);
  }

  /// Check if a given time is within active hours
  bool isWithinActiveHours(DateTime dateTime) {
    return _settings.isWithinActiveHours(dateTime);
  }

  /// Get total weekly active hours
  double get totalWeeklyActiveHours => _settings.totalWeeklyActiveHours;

  /// Get total weekly active minutes
  int get totalWeeklyActiveMinutes => _settings.totalWeeklyActiveMinutes;

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    // Preserve onboarding status
    final wasOnboarded = _settings.hasCompletedOnboarding;
    _settings = UserSettings.defaults;
    _settings = _settings.copyWith(hasCompletedOnboarding: wasOnboarded);
    await _saveSettings();
  }
}
