import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'settings_service.dart';

/// Service for managing all app notifications
///
/// Notification types:
/// 1. Golden Ratio Achievement (80%+ signal with 6+ hours logged)
/// 2. Morning Reminder (configurable wake time, default 8am)
/// 3. Noise Task Warning (1 hour on noise task) 4. Inactivity Reminder (2 hours no activity during active hours)
///
/// Note: NO push notifications while Signal timer is running (reward focus)
/// Live Activities handle the real-time timer display instead
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settings = SettingsService();

  Timer? _noiseCheckTimer;
  Timer? _inactivityCheckTimer;
  DateTime? _noiseTimerStartedAt;
  String? _noiseTaskTitle;
  bool _hasNotifiedNoiseWarning = false;
  bool _isTimerActive = false; // Track if any timer is currently running

  // Notification IDs
  static const int _goldenRatioNotificationId = 10;
  static const int _morningReminderNotificationId = 20;
  static const int _noiseWarningNotificationId = 30;
  static const int _inactivityNotificationId = 40;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone for scheduled notifications
    tz_data.initializeTimeZones();

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: false,
      defaultPresentSound: true,
      notificationCategories: [],
    );

    const initSettings = InitializationSettings(
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions and enable foreground notifications
    final iOS = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iOS != null) {
      await iOS.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Schedule the morning reminder
    await scheduleMorningReminder();

    // Start inactivity monitoring
    _startInactivityMonitoring();
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final iOS = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iOS != null) {
      final granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  // ============================================================
  // 1. GOLDEN RATIO ACHIEVEMENT (80%+ signal with 6+ hours)
  // ============================================================

  /// Check and notify if golden ratio is achieved
  /// Called when time is logged or timer is stopped
  Future<void> checkGoldenRatioAchievement({
    required double signalPercentage,
    required Duration totalTime,
  }) async {
    // Must have 80%+ signal
    if (signalPercentage < 0.8) return;

    // Must have 6+ hours logged
    if (totalTime.inHours < 6) return;

    // Only notify once per day
    if (_settings.goldenRatioNotifiedToday) return;

    await _settings.markGoldenRatioNotified();

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final percentage = (signalPercentage * 100).toInt();

    await _notifications.show(
      _goldenRatioNotificationId,
      'Golden Ratio Achieved! 🎯',
      'You\'ve spent $percentage% of your time on Signal tasks today. Keep it up!',
      details,
    );
  }

  // ============================================================
  // 2. MORNING REMINDER (configurable, default 8am)
  // ============================================================

  /// Schedule the daily morning reminder
  Future<void> scheduleMorningReminder() async {
    // Cancel any existing scheduled notification
    await _notifications.cancel(_morningReminderNotificationId);

    final wakeHour = _settings.wakeUpHour;
    final wakeMinute = _settings.wakeUpMinute;

    // Calculate next occurrence of wake time
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      wakeHour,
      wakeMinute,
    );

    // If wake time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.zonedSchedule(
      _morningReminderNotificationId,
      'Good Morning! ☀️',
      'Time to set your Signal tasks for today. What are the 3-5 things that must get done?',
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  /// Update morning reminder time (call when user changes wake time)
  Future<void> updateMorningReminderTime(int hour, int minute) async {
    await _settings.setWakeUpTime(hour, minute);
    await scheduleMorningReminder();
  }

  // ============================================================
  // 3. NOISE TASK WARNING (1 hour on noise)
  // ============================================================

  /// Start monitoring a noise task timer
  /// Only sends notifications for NOISE tasks, not Signal
  void startNoiseTimerMonitoring({
    required String taskTitle,
    required DateTime startedAt,
  }) {
    _noiseTaskTitle = taskTitle;
    _noiseTimerStartedAt = startedAt;
    _hasNotifiedNoiseWarning = false;
    _isTimerActive = true; // Mark timer as active

    // Check every minute if we've exceeded the threshold
    _noiseCheckTimer?.cancel();
    _noiseCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkNoiseTimerWarning();
    });
  }

  /// Stop monitoring noise timer
  void stopNoiseTimerMonitoring() {
    _noiseCheckTimer?.cancel();
    _noiseCheckTimer = null;
    _noiseTaskTitle = null;
    _noiseTimerStartedAt = null;
    _hasNotifiedNoiseWarning = false;
    _isTimerActive = false; // Mark timer as inactive
  }

  /// Mark that a timer has started (for Signal tasks that don't use noise monitoring)
  void markTimerStarted() {
    _isTimerActive = true;
  }

  /// Mark that a timer has stopped
  void markTimerStopped() {
    _isTimerActive = false;
  }

  /// Check if noise timer has exceeded threshold
  Future<void> _checkNoiseTimerWarning() async {
    if (_noiseTimerStartedAt == null || _hasNotifiedNoiseWarning) return;

    final elapsed = DateTime.now().difference(_noiseTimerStartedAt!);
    final thresholdMinutes = _settings.noiseAlertMinutes;

    if (elapsed.inMinutes >= thresholdMinutes) {
      _hasNotifiedNoiseWarning = true;
      await _showNoiseWarningNotification();
    }
  }

  /// Show warning that user has been on noise too long
  Future<void> _showNoiseWarningNotification() async {
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final taskName = _noiseTaskTitle ?? 'a noise task';

    await _notifications.show(
      _noiseWarningNotificationId,
      'Time to Lock Back In 🎯',
      'You\'ve been on "$taskName" for over an hour. Consider switching to a Signal task.',
      details,
    );
  }

  // ============================================================
  // 4. INACTIVITY REMINDER (2 hours during active hours)
  // ============================================================

  /// Start monitoring for inactivity
  void _startInactivityMonitoring() {
    // Check every 15 minutes
    _inactivityCheckTimer?.cancel();
    _inactivityCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkInactivity();
    });
  }

  /// Record that user performed an activity (started timer, logged time, etc.)
  Future<void> recordActivity() async {
    await _settings.recordActivity();
  }

  /// Check if user has been inactive too long
  Future<void> _checkInactivity() async {
    // Don't notify if a timer is currently running - user is actively working
    if (_isTimerActive) return;

    // Only check during active hours
    if (!_settings.isWithinActiveHours) return;

    final lastActivity = _settings.lastActivityTimestamp;
    if (lastActivity == null) return;

    final elapsed = DateTime.now().difference(lastActivity);
    final thresholdMinutes = _settings.inactivityAlertMinutes;

    if (elapsed.inMinutes >= thresholdMinutes) {
      await _showInactivityNotification();
      // Record this check as activity to prevent spam
      await _settings.recordActivity();
    }
  }

  /// Show inactivity reminder notification
  Future<void> _showInactivityNotification() async {
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      _inactivityNotificationId,
      'Time Check ⏰',
      'You haven\'t logged any time in a while. What are you working on?',
      details,
    );
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Could navigate to specific screen based on notification ID
    // For now, just opening the app is sufficient
  }

  /// Cancel all notifications and timers
  Future<void> cancelAll() async {
    _noiseCheckTimer?.cancel();
    _inactivityCheckTimer?.cancel();
    await _notifications.cancelAll();
  }

  /// Dispose resources
  void dispose() {
    _noiseCheckTimer?.cancel();
    _inactivityCheckTimer?.cancel();
  }
}
