import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

/// Provider for managing user settings
class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  UserSettings _settings = UserSettings.defaults;

  SettingsProvider(this._storageService) {
    _loadSettings();
  }

  /// Current user settings
  UserSettings get settings => _settings;

  /// Whether onboarding has been completed
  bool get hasCompletedOnboarding => _settings.hasCompletedOnboarding;

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

  /// Today's schedule
  DaySchedule get todaySchedule => _settings.todaySchedule;

  /// Weekly schedule map
  Map<int, DaySchedule> get weeklySchedule => _settings.weeklySchedule;

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
