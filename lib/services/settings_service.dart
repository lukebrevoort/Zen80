import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user settings/preferences
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _wakeUpHourKey = 'wake_up_hour';
  static const String _wakeUpMinuteKey = 'wake_up_minute';
  static const String _noiseAlertMinutesKey = 'noise_alert_minutes';
  static const String _inactivityAlertMinutesKey = 'inactivity_alert_minutes';
  static const String _lastActivityTimestampKey = 'last_activity_timestamp';
  static const String _lastGoldenRatioDateKey = 'last_golden_ratio_date';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  // Defaults
  static const int defaultWakeUpHour = 8;
  static const int defaultWakeUpMinute = 0;
  static const int defaultNoiseAlertMinutes = 60; // 1 hour
  static const int defaultInactivityAlertMinutes = 120; // 2 hours

  /// Initialize the settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get wake up time hour (0-23)
  int get wakeUpHour => _prefs?.getInt(_wakeUpHourKey) ?? defaultWakeUpHour;

  /// Get wake up time minute (0-59)
  int get wakeUpMinute =>
      _prefs?.getInt(_wakeUpMinuteKey) ?? defaultWakeUpMinute;

  /// Set wake up time
  Future<void> setWakeUpTime(int hour, int minute) async {
    await _prefs?.setInt(_wakeUpHourKey, hour);
    await _prefs?.setInt(_wakeUpMinuteKey, minute);
  }

  /// Get the wake up time as DateTime for today
  DateTime get todayWakeUpTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, wakeUpHour, wakeUpMinute);
  }

  /// Get the end of active hours (wake up + 8 hours)
  DateTime get todayActiveHoursEnd {
    return todayWakeUpTime.add(const Duration(hours: 8));
  }

  /// Check if current time is within active hours
  bool get isWithinActiveHours {
    final now = DateTime.now();
    return now.isAfter(todayWakeUpTime) && now.isBefore(todayActiveHoursEnd);
  }

  /// Get noise alert threshold in minutes
  int get noiseAlertMinutes =>
      _prefs?.getInt(_noiseAlertMinutesKey) ?? defaultNoiseAlertMinutes;

  /// Set noise alert threshold in minutes
  Future<void> setNoiseAlertMinutes(int minutes) async {
    await _prefs?.setInt(_noiseAlertMinutesKey, minutes);
  }

  /// Get inactivity alert threshold in minutes
  int get inactivityAlertMinutes =>
      _prefs?.getInt(_inactivityAlertMinutesKey) ??
      defaultInactivityAlertMinutes;

  /// Set inactivity alert threshold in minutes
  Future<void> setInactivityAlertMinutes(int minutes) async {
    await _prefs?.setInt(_inactivityAlertMinutesKey, minutes);
  }

  /// Get last activity timestamp
  DateTime? get lastActivityTimestamp {
    final timestamp = _prefs?.getInt(_lastActivityTimestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set last activity timestamp
  Future<void> setLastActivityTimestamp(DateTime time) async {
    await _prefs?.setInt(
      _lastActivityTimestampKey,
      time.millisecondsSinceEpoch,
    );
  }

  /// Update last activity to now
  Future<void> recordActivity() async {
    await setLastActivityTimestamp(DateTime.now());
  }

  /// Check if golden ratio was already notified today
  bool get goldenRatioNotifiedToday {
    final lastDate = _prefs?.getString(_lastGoldenRatioDateKey);
    if (lastDate == null) return false;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return lastDate == todayStr;
  }

  /// Mark golden ratio as notified for today
  Future<void> markGoldenRatioNotified() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await _prefs?.setString(_lastGoldenRatioDateKey, todayStr);
  }

  /// Reset golden ratio notification for a new day
  Future<void> resetGoldenRatioIfNewDay() async {
    final lastDate = _prefs?.getString(_lastGoldenRatioDateKey);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (lastDate != todayStr) {
      await _prefs?.remove(_lastGoldenRatioDateKey);
    }
  }

  /// Force reset golden ratio notification (for testing)
  Future<void> resetGoldenRatioNotification() async {
    await _prefs?.remove(_lastGoldenRatioDateKey);
  }

  /// Check if onboarding has been completed
  bool get onboardingCompleted =>
      _prefs?.getBool(_onboardingCompletedKey) ?? false;

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    await _prefs?.setBool(_onboardingCompletedKey, true);
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    await _prefs?.remove(_onboardingCompletedKey);
  }
}
