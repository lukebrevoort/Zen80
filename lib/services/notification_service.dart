import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/signal_task.dart';
import '../models/time_slot.dart';
import 'settings_service.dart';

/// Service for managing all app notifications
///
/// Notification types per IMPLEMENTATION_PLAN.md:
/// 1. Task Starting Soon - X minutes before planned start
/// 2. Task Start Prompt - At planned start time
/// 3. Task Ending Soon - X minutes before planned end
/// 4. Task Auto-Ended - When time slot ends (if autoEnd)
/// 5. Next Task Reminder - After ending, if another task scheduled
/// 6. Rollover Morning - At active start time for incomplete tasks
/// 7. Golden Ratio Achievement - 80%+ signal with 6+ hours (legacy)
/// 8. Morning Planning Reminder - Configurable wake time (legacy)
/// 9. Noise Task Warning - 1 hour on noise (legacy)
/// 10. Inactivity Reminder - 2 hours no activity (legacy)
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

  // Notification IDs - base IDs for different notification types
  static const int _goldenRatioNotificationId = 10;
  static const int _morningReminderNotificationId = 20;
  static const int _noiseWarningNotificationId = 30;
  static const int _inactivityNotificationId = 40;
  static const int _productivityNotificationId =
      50; // For positive reinforcement
  static const int _smartNudgeNotificationId =
      55; // For smart nudge notifications
  static const int _taskStartingSoonBaseId = 100; // +taskId.hashCode
  static const int _taskStartPromptBaseId = 200; // +taskId.hashCode
  static const int _taskEndingSoonBaseId = 300; // +taskId.hashCode
  static const int _taskAutoEndedBaseId = 400; // +taskId.hashCode
  static const int _nextTaskReminderBaseId = 500; // +taskId.hashCode
  static const int _rolloverMorningBaseId = 600; // +taskId.hashCode

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone for scheduled notifications
    tz_data.initializeTimeZones();

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: false,
      defaultPresentSound: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'taskStart',
          actions: [
            DarwinNotificationAction.plain('start', 'Start Task'),
            DarwinNotificationAction.plain('snooze', 'Snooze 5m'),
          ],
        ),
        DarwinNotificationCategory(
          'taskEnding',
          actions: [
            DarwinNotificationAction.plain('continue', 'Continue'),
            DarwinNotificationAction.plain('end', 'End Now'),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
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
  // NEW: TASK SCHEDULING NOTIFICATIONS
  // ============================================================

  /// Schedule all notifications for a task's time slots
  /// Call this when user finalizes their daily schedule
  Future<void> scheduleTaskNotifications({
    required SignalTask task,
    int minutesBeforeStart = 5,
    int minutesBeforeEnd = 5,
  }) async {
    for (final slot in task.timeSlots) {
      if (slot.isDiscarded || slot.isCompleted) continue;

      await _scheduleSlotNotifications(
        task: task,
        slot: slot,
        minutesBeforeStart: minutesBeforeStart,
        minutesBeforeEnd: minutesBeforeEnd,
      );
    }
  }

  /// Schedule notifications for a specific time slot
  /// This is the public version that can be called from scheduling screens
  /// when a single slot is added or rescheduled.
  Future<void> scheduleSlotNotifications({
    required SignalTask task,
    required TimeSlot slot,
    int minutesBeforeStart = 5,
    int minutesBeforeEnd = 5,
  }) async {
    if (slot.isDiscarded || slot.isCompleted) return;

    await _scheduleSlotNotifications(
      task: task,
      slot: slot,
      minutesBeforeStart: minutesBeforeStart,
      minutesBeforeEnd: minutesBeforeEnd,
    );
  }

  /// Schedule notifications for a specific time slot (internal implementation)
  Future<void> _scheduleSlotNotifications({
    required SignalTask task,
    required TimeSlot slot,
    required int minutesBeforeStart,
    required int minutesBeforeEnd,
  }) async {
    final now = DateTime.now();

    // Calculate unique notification ID for this slot
    final slotIdHash = slot.id.hashCode.abs() % 10000;

    // 1. Task Starting Soon (X min before planned start)
    final startingSoonTime = slot.plannedStartTime.subtract(
      Duration(minutes: minutesBeforeStart),
    );
    if (startingSoonTime.isAfter(now)) {
      await _scheduleNotification(
        id: _taskStartingSoonBaseId + slotIdHash,
        title: '${task.title} starts soon',
        body: 'Starting in $minutesBeforeStart minutes. Ready to focus?',
        scheduledTime: startingSoonTime,
        category: 'taskStart',
      );
    }

    // 2. Task Start Prompt (at planned start time)
    if (slot.plannedStartTime.isAfter(now)) {
      await _scheduleNotification(
        id: _taskStartPromptBaseId + slotIdHash,
        title: 'Time to start: ${task.title}',
        body: 'Your scheduled focus time is now. Tap to begin.',
        scheduledTime: slot.plannedStartTime,
        category: 'taskStart',
        isTimeSensitive: true,
      );
    }

    // 3. Task Ending Soon (X min before planned end)
    final endingSoonTime = slot.plannedEndTime.subtract(
      Duration(minutes: minutesBeforeEnd),
    );
    if (endingSoonTime.isAfter(now)) {
      await _scheduleNotification(
        id: _taskEndingSoonBaseId + slotIdHash,
        title: '${task.title} ends in $minutesBeforeEnd minutes',
        body: 'Wrap up or continue past the scheduled time.',
        scheduledTime: endingSoonTime,
        category: 'taskEnding',
      );
    }
  }

  /// Schedule a notification at a specific time
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? category,
    bool isTimeSensitive = false,
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      interruptionLevel: isTimeSensitive
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
      categoryIdentifier: category,
    );

    final details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel all notifications for a specific time slot
  Future<void> cancelSlotNotifications(String slotId) async {
    final slotIdHash = slotId.hashCode.abs() % 10000;

    await _notifications.cancel(_taskStartingSoonBaseId + slotIdHash);
    await _notifications.cancel(_taskStartPromptBaseId + slotIdHash);
    await _notifications.cancel(_taskEndingSoonBaseId + slotIdHash);
    await _notifications.cancel(_taskAutoEndedBaseId + slotIdHash);
  }

  /// Cancel all notifications for a task
  Future<void> cancelTaskNotifications(SignalTask task) async {
    for (final slot in task.timeSlots) {
      await cancelSlotNotifications(slot.id);
    }
  }

  /// Show immediate "Task Auto-Ended" notification
  Future<void> showTaskAutoEndedNotification({
    required String taskTitle,
    required Duration actualDuration,
  }) async {
    final durationStr = _formatDuration(actualDuration);

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
      _taskAutoEndedBaseId,
      '$taskTitle session complete! 🎯',
      'Great work! You focused for $durationStr.',
      details,
    );
  }

  /// Show "Next Task Reminder" notification
  Future<void> showNextTaskReminder({
    required String nextTaskTitle,
    required Duration timeUntilStart,
  }) async {
    final minutesUntil = timeUntilStart.inMinutes;
    final timeStr = minutesUntil > 0 ? 'in $minutesUntil minutes' : 'now';

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
      _nextTaskReminderBaseId,
      'Up next: $nextTaskTitle',
      'Your next Signal task starts $timeStr.',
      details,
    );
  }

  /// Schedule rollover morning notification for incomplete tasks
  Future<void> scheduleRolloverMorningNotification({
    required List<SignalTask> incompleteTasks,
    required DateTime morningTime,
  }) async {
    if (incompleteTasks.isEmpty) return;

    final now = DateTime.now();
    if (morningTime.isBefore(now)) return;

    final taskCount = incompleteTasks.length;
    final totalMinutes = incompleteTasks.fold<int>(
      0,
      (sum, task) => sum + task.remainingMinutes,
    );

    final formattedTime = _formatDuration(Duration(minutes: totalMinutes));

    final title = taskCount == 1
        ? 'Continue "${incompleteTasks.first.title}"?'
        : '$taskCount tasks to continue';

    final body = taskCount == 1
        ? 'You have ${incompleteTasks.first.formattedRemainingTime} remaining. Add to today?'
        : 'You have $formattedTime of remaining work. Add to today\'s schedule?';

    await _scheduleNotification(
      id: _rolloverMorningBaseId,
      title: title,
      body: body,
      scheduledTime: morningTime,
      isTimeSensitive: true,
    );
  }

  /// Cancel rollover morning notification
  Future<void> cancelRolloverMorningNotification() async {
    await _notifications.cancel(_rolloverMorningBaseId);
  }

  // ============================================================
  // LEGACY: GOLDEN RATIO ACHIEVEMENT (80%+ signal with 6+ hours)
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
  // LEGACY: MORNING REMINDER (configurable, default 8am)
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
  // LEGACY: NOISE TASK WARNING (1 hour on noise)
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
  // LEGACY: INACTIVITY REMINDER (2 hours during active hours)
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
  // NEW: SMART CENTRALIZED NOTIFICATIONS (Fix for notification bug)
  // ============================================================

  /// Update notifications when user starts working on a task
  /// This cancels scheduled notifications for tasks the user isn't working on
  /// and ensures the active task's notifications are accurate
  Future<void> onTimerStarted(
    SignalTask activeTask,
    TimeSlot activeSlot,
  ) async {
    // Mark timer as active so inactivity notifications don't fire
    markTimerStarted();

    // Update notifications to show accurate time for the actual task being worked on
    await _rescheduleNotificationsForActiveTask(activeTask, activeSlot);

    // Show positive reinforcement for starting work
    await _showProductivityNotification(activeTask, activeSlot);
  }

  /// Update notifications when user stops working on a task
  /// This can trigger nudge notifications if appropriate
  Future<void> onTimerStopped(SignalTask task, TimeSlot slot) async {
    // Mark timer as inactive so inactivity monitoring can resume
    markTimerStopped();

    // Cancel notifications for this task since timer is stopped
    await cancelSlotNotifications(slot.id);

    // Check if we should send nudge notifications (user is not doing any Signal task)
    await _checkForNudgeNotification();
  }

  /// Cancel scheduled notifications for all inactive tasks
  /// This should be called from SignalTaskProvider where all tasks are accessible
  Future<void> cancelNotificationsForInactiveTasks(
    List<SignalTask> allTasks,
    String activeTaskId,
  ) async {
    for (final task in allTasks) {
      if (task.id != activeTaskId) {
        await cancelTaskNotifications(task);
      }
    }
  }

  /// Reschedule notifications to reflect the actual task being worked on
  Future<void> _rescheduleNotificationsForActiveTask(
    SignalTask task,
    TimeSlot slot,
  ) async {
    // Cancel any existing notifications for this slot first to avoid duplicates
    await cancelSlotNotifications(slot.id);

    // Schedule updated notifications showing the actual task
    // Use a short time before end since we're already in the task
    await _scheduleSlotNotifications(
      task: task,
      slot: slot,
      minutesBeforeStart: 0, // Task already started
      minutesBeforeEnd: 5,
    );
  }

  /// Show positive reinforcement notification for productive work
  Future<void> _showProductivityNotification(
    SignalTask task,
    TimeSlot slot,
  ) async {
    // Calculate total time including current session (not just accumulated)
    final currentSessionTime = slot.actualStartTime != null && slot.isActive
        ? DateTime.now().difference(slot.actualStartTime!)
        : Duration.zero;
    final totalTime =
        Duration(seconds: slot.accumulatedSeconds) + currentSessionTime;
    final elapsedStr = _formatDuration(totalTime);

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false, // Don't interrupt - this is positive reinforcement
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      _productivityNotificationId,
      'Working on ${task.title} 🎯',
      'Great focus! You\'ve spent $elapsedStr on this task.',
      details,
    );
  }

  /// Check if we should send nudge notifications
  /// Only sends when user is NOT doing any Signal task
  /// Leverages the existing inactivity monitoring system
  Future<void> _checkForNudgeNotification() async {
    // The inactivity monitoring system handles periodic checks
    // This method is called specifically when a timer stops
    // If we've been inactive long enough, show a smart nudge
    await _checkInactivity();
  }

  /// Show intelligent nudge notification
  Future<void> _showSmartNudgeNotification() async {
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
      _smartNudgeNotificationId,
      'Time to Focus ⏰',
      'You haven\'t logged any Signal time recently. What\'s the most important thing to work on?',
      details,
    );
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Format duration as readable string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle action buttons
    final actionId = response.actionId;
    if (actionId != null) {
      switch (actionId) {
        case 'start':
          // TODO: Navigate to task and start timer
          break;
        case 'snooze':
          // TODO: Snooze notification by 5 minutes
          break;
        case 'continue':
          // TODO: Continue past planned end time
          break;
        case 'end':
          // TODO: End the current task
          break;
      }
    }
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
