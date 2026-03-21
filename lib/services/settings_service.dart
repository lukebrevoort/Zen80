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
  static const String _enableTaskNudgesKey = 'enable_task_nudges';
  static const String _taskNudgeFrequencyMinutesKey =
      'task_nudge_frequency_minutes';
  static const String _taskNudgeQuietStartHourKey =
      'task_nudge_quiet_start_hour';
  static const String _taskNudgeQuietEndHourKey = 'task_nudge_quiet_end_hour';
  static const String _lastTaskCreatedTimestampKey =
      'last_task_created_timestamp';
  static const String _taskNudgeCountDateKey = 'task_nudge_count_date';
  static const String _taskNudgeCountValueKey = 'task_nudge_count_value';
  static const String _taskNudgeLastSentAtKey = 'task_nudge_last_sent_at';
  static const String _taskNudgeLastVariantKey = 'task_nudge_last_variant';
  static const String _taskNudgeMetricTotalSentKey =
      'task_nudge_metric_total_sent';
  static const String _taskNudgeMetricMotivationalKey =
      'task_nudge_metric_motivational';
  static const String _taskNudgeMetricPlayfulKey = 'task_nudge_metric_playful';
  static const String _taskNudgeMetricPracticalKey =
      'task_nudge_metric_practical';
  static const String _taskNudgeMetricContextualKey =
      'task_nudge_metric_contextual';

  // Defaults
  static const int defaultWakeUpHour = 8;
  static const int defaultWakeUpMinute = 0;
  static const int defaultNoiseAlertMinutes = 60; // 1 hour
  static const int defaultInactivityAlertMinutes = 120; // 2 hours
  static const bool defaultEnableTaskNudges = true;
  static const int defaultTaskNudgeFrequencyMinutes = 180;
  static const int defaultTaskNudgeQuietStartHour = 21;
  static const int defaultTaskNudgeQuietEndHour = 8;
  static const int defaultTaskNudgeMaxPerDay = 3;

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

  /// Whether daily "no tasks yet" nudges are enabled.
  bool get enableTaskNudges =>
      _prefs?.getBool(_enableTaskNudgesKey) ?? defaultEnableTaskNudges;

  Future<void> setEnableTaskNudges(bool enabled) async {
    await _prefs?.setBool(_enableTaskNudgesKey, enabled);
  }

  /// Minimum minutes between "no tasks yet" nudges.
  int get taskNudgeFrequencyMinutes {
    final value =
        _prefs?.getInt(_taskNudgeFrequencyMinutesKey) ??
        defaultTaskNudgeFrequencyMinutes;
    return value.clamp(60, 360);
  }

  Future<void> setTaskNudgeFrequencyMinutes(int minutes) async {
    final clamped = minutes.clamp(60, 360);
    await _prefs?.setInt(_taskNudgeFrequencyMinutesKey, clamped);
  }

  int get taskNudgeQuietStartHour {
    final value =
        _prefs?.getInt(_taskNudgeQuietStartHourKey) ??
        defaultTaskNudgeQuietStartHour;
    return value.clamp(0, 23);
  }

  int get taskNudgeQuietEndHour {
    final value =
        _prefs?.getInt(_taskNudgeQuietEndHourKey) ??
        defaultTaskNudgeQuietEndHour;
    return value.clamp(0, 23);
  }

  Future<void> setTaskNudgeQuietHours({
    required int startHour,
    required int endHour,
  }) async {
    await _prefs?.setInt(_taskNudgeQuietStartHourKey, startHour.clamp(0, 23));
    await _prefs?.setInt(_taskNudgeQuietEndHourKey, endHour.clamp(0, 23));
  }

  DateTime? get lastTaskCreatedTimestamp {
    final timestamp = _prefs?.getInt(_lastTaskCreatedTimestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> markTaskCreated({DateTime? at}) async {
    final when = at ?? DateTime.now();
    await _prefs?.setInt(
      _lastTaskCreatedTimestampKey,
      when.millisecondsSinceEpoch,
    );
  }

  bool get hasCreatedTaskToday {
    final last = lastTaskCreatedTimestamp;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  int get taskNudgeCountToday {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final date = _prefs?.getString(_taskNudgeCountDateKey);
    if (date != today) return 0;
    return _prefs?.getInt(_taskNudgeCountValueKey) ?? 0;
  }

  Future<void> incrementTaskNudgeCountToday() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final currentDate = _prefs?.getString(_taskNudgeCountDateKey);
    final currentCount = currentDate == today
        ? (_prefs?.getInt(_taskNudgeCountValueKey) ?? 0)
        : 0;

    await _prefs?.setString(_taskNudgeCountDateKey, today);
    await _prefs?.setInt(_taskNudgeCountValueKey, currentCount + 1);
  }

  DateTime? get lastTaskNudgeSentAt {
    final millis = _prefs?.getInt(_taskNudgeLastSentAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastTaskNudgeSentAt(DateTime sentAt) async {
    await _prefs?.setInt(
      _taskNudgeLastSentAtKey,
      sentAt.millisecondsSinceEpoch,
    );
  }

  int? get lastTaskNudgeVariantIndex =>
      _prefs?.getInt(_taskNudgeLastVariantKey);

  Future<void> setLastTaskNudgeVariantIndex(int index) async {
    await _prefs?.setInt(_taskNudgeLastVariantKey, index);
  }

  Future<void> recordTaskNudgeMetric(String style) async {
    await _prefs?.setInt(
      _taskNudgeMetricTotalSentKey,
      (_prefs?.getInt(_taskNudgeMetricTotalSentKey) ?? 0) + 1,
    );

    final styleKey = switch (style) {
      'motivational' => _taskNudgeMetricMotivationalKey,
      'playful' => _taskNudgeMetricPlayfulKey,
      'practical' => _taskNudgeMetricPracticalKey,
      'contextual' => _taskNudgeMetricContextualKey,
      _ => null,
    };

    if (styleKey == null) return;

    await _prefs?.setInt(styleKey, (_prefs?.getInt(styleKey) ?? 0) + 1);
  }

  Future<void> resetTaskNudgeStateForToday() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    await _prefs?.setString(_taskNudgeCountDateKey, today);
    await _prefs?.setInt(_taskNudgeCountValueKey, defaultTaskNudgeMaxPerDay);
    await _prefs?.remove(_taskNudgeLastSentAtKey);
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
