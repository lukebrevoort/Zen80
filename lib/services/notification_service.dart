import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/signal_task.dart';
import '../models/time_slot.dart';
import 'storage_service.dart';
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
  final StorageService _storage = StorageService();
  final Random _random = Random();

  Timer? _noiseCheckTimer;
  Timer? _inactivityCheckTimer;
  Timer? _taskNudgeCheckTimer;
  DateTime? _noiseTimerStartedAt;
  String? _noiseTaskTitle;
  bool _hasNotifiedNoiseWarning = false;
  bool _isTimerActive = false; // Track if any timer is currently running

  /// Optional callbacks for actionable timer notifications.
  Future<void> Function(String taskId, String slotId)? _onEndActionRequested;
  Future<void> Function(String taskId, String slotId)?
  _onContinueActionRequested;
  _PendingTimerAction? _pendingTimerAction;

  set onEndActionRequested(
    Future<void> Function(String taskId, String slotId)? handler,
  ) {
    _onEndActionRequested = handler;
    unawaited(_flushPendingTimerAction());
  }

  Future<void> Function(String taskId, String slotId)?
  get onEndActionRequested => _onEndActionRequested;

  set onContinueActionRequested(
    Future<void> Function(String taskId, String slotId)? handler,
  ) {
    _onContinueActionRequested = handler;
    unawaited(_flushPendingTimerAction());
  }

  Future<void> Function(String taskId, String slotId)?
  get onContinueActionRequested => _onContinueActionRequested;

  // Notification IDs - base IDs for different notification types
  static const int _goldenRatioNotificationId = 10;
  static const int _morningReminderNotificationId = 20;
  static const int _noiseWarningNotificationId = 30;
  static const int _inactivityNotificationId = 40;
  static const int _smartNudgeNotificationId =
      55; // For smart nudge notifications
  static const int _taskStartingSoonBaseId = 100; // +taskId.hashCode
  static const int _taskStartPromptBaseId = 200; // +taskId.hashCode
  static const int _taskEndingSoonBaseId = 300; // +taskId.hashCode
  static const int _taskAutoEndedBaseId = 400; // +taskId.hashCode
  static const int _nextTaskReminderBaseId = 500; // +taskId.hashCode
  static const int _rolloverMorningBaseId = 600; // +taskId.hashCode
  static const Duration _autoEndedNotificationDelay = Duration(seconds: 20);
  static const Duration _nextTaskNotificationDelay = Duration(seconds: 5);

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

    // Start daily task nudge monitoring
    _startTaskNudgeMonitoring();

    // Evaluate quickly on launch so users receive nudges without waiting.
    Future.delayed(const Duration(minutes: 1), () {
      unawaited(_checkDailyTaskNudges());
    });
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
    if (_isTimerActive) return;
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
    if (_isTimerActive) return;
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
    if (minutesBeforeStart > 0) {
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
    }

    // 3. Task Ending Soon (X min before planned end)
    if (minutesBeforeEnd > 0) {
      final endingSoonTime = slot.plannedEndTime.subtract(
        Duration(minutes: minutesBeforeEnd),
      );
      if (endingSoonTime.isAfter(now)) {
        await _scheduleNotification(
          id: _taskEndingSoonBaseId + slotIdHash,
          title: '${task.title} ends in $minutesBeforeEnd minutes',
          body: 'Wrap up or continue past the scheduled time.',
          scheduledTime: endingSoonTime,
        );
      }
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
    String? payload,
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
      payload: payload,
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
    await _notifications.cancel(_nextTaskReminderBaseId + slotIdHash);
  }

  /// Schedule completion + next-task notifications for an active timer.
  ///
  /// These are scheduled with the OS so they still fire when the app is backgrounded.
  Future<void> scheduleActiveTimerNotifications({
    required SignalTask activeTask,
    required TimeSlot activeSlot,
    required List<SignalTask> allTasks,
    required bool enableNextTaskReminders,
  }) async {
    // Clear any stale notifications for this slot before re-scheduling.
    await cancelSlotNotifications(activeSlot.id);

    // Only schedule for slots that should auto-end.
    if (!activeSlot.autoEnd || activeSlot.wasManualContinue) return;
    if (activeSlot.isDiscarded || activeSlot.isCompleted) return;

    final now = DateTime.now();
    final completionTime = activeSlot.plannedEndTime.add(
      _autoEndedNotificationDelay,
    );
    if (completionTime.isBefore(now)) return;

    final slotIdHash = activeSlot.id.hashCode.abs() % 10000;
    final timerPayload = _buildTimerPayload(activeTask.id, activeSlot.id);
    final plannedDuration = activeSlot.plannedEndTime.difference(
      activeSlot.plannedStartTime,
    );

    final endingSoonTime = activeSlot.plannedEndTime.subtract(
      const Duration(minutes: 5),
    );
    if (endingSoonTime.isAfter(now)) {
      await _scheduleNotification(
        id: _taskEndingSoonBaseId + slotIdHash,
        title: '${activeTask.title} almost done',
        body: 'Auto-stop is approaching. Continue in-app to add 50% more time.',
        scheduledTime: endingSoonTime,
        category: 'taskEnding',
        isTimeSensitive: true,
        payload: timerPayload,
      );
    }

    await _scheduleNotification(
      id: _taskAutoEndedBaseId + slotIdHash,
      title: '${activeTask.title} session complete! 🎯',
      body: 'Great work! You focused for ${_formatDuration(plannedDuration)}.',
      scheduledTime: completionTime,
      isTimeSensitive: true,
    );

    if (!enableNextTaskReminders) return;

    final nextSlotInfo = _findNextSlotAfter(
      allTasks: allTasks,
      after: activeSlot.plannedEndTime,
      excludingSlotId: activeSlot.id,
    );
    if (nextSlotInfo == null) return;

    final nextSlot = nextSlotInfo.slot;
    final minutesUntilNext = nextSlot.plannedStartTime
        .difference(activeSlot.plannedEndTime)
        .inMinutes;
    final startLabel = _formatClockTime(nextSlot.plannedStartTime);
    final nextBody = minutesUntilNext > 0
        ? 'Your next Signal task starts in $minutesUntilNext minutes at $startLabel.'
        : 'Your next Signal task starts at $startLabel.';

    await _scheduleNotification(
      id: _nextTaskReminderBaseId + slotIdHash,
      title: 'Up next: ${nextSlotInfo.task.title}',
      body: nextBody,
      scheduledTime: completionTime.add(_nextTaskNotificationDelay),
      isTimeSensitive: true,
    );
  }

  /// Cancel all notifications for a task
  Future<void> cancelTaskNotifications(SignalTask task) async {
    for (final slot in task.timeSlots) {
      await cancelSlotNotifications(slot.id);
    }
  }

  /// Cancel all task notifications for a list of tasks
  Future<void> cancelTaskNotificationsForTasks(List<SignalTask> tasks) async {
    for (final task in tasks) {
      await cancelTaskNotifications(task);
    }
  }

  /// Refresh all task notifications based on current state
  Future<void> refreshTaskNotifications({
    required List<SignalTask> tasks,
    required bool enableStartReminders,
    required bool enableEndReminders,
    required int minutesBeforeStart,
    required int minutesBeforeEnd,
  }) async {
    await cancelTaskNotificationsForTasks(tasks);

    if (_isTimerActive) return;
    if (!enableStartReminders && !enableEndReminders) return;

    final startMinutes = enableStartReminders ? minutesBeforeStart : 0;
    final endMinutes = enableEndReminders ? minutesBeforeEnd : 0;

    for (final task in tasks) {
      await scheduleTaskNotifications(
        task: task,
        minutesBeforeStart: startMinutes,
        minutesBeforeEnd: endMinutes,
      );
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

  /// Show immediate "Midnight Cutoff" notification when timer is force-stopped at 11:59 PM
  /// This explains to the user why their timer was automatically stopped
  Future<void> showMidnightCutoffNotification({
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
      _taskAutoEndedBaseId +
          1, // Use a slightly different ID to avoid collision
      '$taskTitle stopped at midnight 🌙',
      'Timer auto-stopped to prevent overnight tracking. You worked $durationStr today.',
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

  /// Start monitoring for users that have not added any tasks today.
  void _startTaskNudgeMonitoring() {
    _taskNudgeCheckTimer?.cancel();
    _taskNudgeCheckTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(_checkDailyTaskNudges());
    });
  }

  /// Refresh nudge behavior after settings changes.
  Future<void> refreshTaskNudgePreferences() async {
    if (!_settings.enableTaskNudges) {
      await _notifications.cancel(_smartNudgeNotificationId);
    }
    await _checkDailyTaskNudges();
  }

  /// Record that user created a task and stop nudge flow for the day.
  Future<void> onTaskCreatedForDate(DateTime scheduledDate) async {
    if (!_isSameDay(scheduledDate, DateTime.now())) return;

    await _settings.markTaskCreated();
    await _settings.resetTaskNudgeStateForToday();
    await _notifications.cancel(_smartNudgeNotificationId);
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

    // Ensure no task notifications fire while actively working
    await cancelSlotNotifications(activeSlot.id);
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

  /// Check if we should send nudge notifications
  /// Only sends when user is NOT doing any Signal task
  /// Leverages the existing inactivity monitoring system
  Future<void> _checkForNudgeNotification() async {
    // The inactivity monitoring system handles periodic checks
    // This method is called specifically when a timer stops
    // If we've been inactive long enough, show a smart nudge
    await _checkInactivity();
    await _checkDailyTaskNudges();
  }

  /// Check and send daily nudges when no tasks have been added today.
  Future<void> _checkDailyTaskNudges() async {
    if (_isTimerActive) return;
    if (!_settings.enableTaskNudges) return;
    if (_isWithinQuietHours(DateTime.now())) return;

    final tasksToday = _storage.getSignalTasksForDate(DateTime.now());
    if (tasksToday.isNotEmpty || _settings.hasCreatedTaskToday) {
      await _notifications.cancel(_smartNudgeNotificationId);
      await _settings.resetTaskNudgeStateForToday();
      return;
    }

    if (_settings.taskNudgeCountToday >=
        SettingsService.defaultTaskNudgeMaxPerDay) {
      return;
    }

    final lastSentAt = _settings.lastTaskNudgeSentAt;
    if (lastSentAt != null) {
      final elapsed = DateTime.now().difference(lastSentAt);
      if (elapsed.inMinutes < _settings.taskNudgeFrequencyMinutes) {
        return;
      }
    }

    await _showSmartNudgeNotification();
  }

  bool _isWithinQuietHours(DateTime now) {
    final startHour = _settings.taskNudgeQuietStartHour;
    final endHour = _settings.taskNudgeQuietEndHour;

    if (startHour == endHour) {
      return true;
    }

    if (startHour < endHour) {
      return now.hour >= startHour && now.hour < endHour;
    }

    return now.hour >= startHour || now.hour < endHour;
  }

  /// Show intelligent nudge notification with rotating friendly variants.
  Future<void> _showSmartNudgeNotification() async {
    final variant = _pickNudgeVariant();

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
      variant.title,
      variant.body,
      details,
    );

    await _settings.incrementTaskNudgeCountToday();
    await _settings.setLastTaskNudgeSentAt(DateTime.now());
    await _settings.setLastTaskNudgeVariantIndex(variant.index);
    await _settings.recordTaskNudgeMetric(variant.style.name);
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  _TaskNudgeVariant _pickNudgeVariant() {
    const variants = <_TaskNudgeVariant>[
      _TaskNudgeVariant(
        index: 0,
        style: _TaskNudgeStyle.motivational,
        title: 'Tiny start, big momentum',
        body:
            'One task is enough to get today moving. What feels most important?',
      ),
      _TaskNudgeVariant(
        index: 1,
        style: _TaskNudgeStyle.playful,
        title: 'Your list is waiting :)',
        body: 'Future-you loves a quick plan. Add one task and keep it light.',
      ),
      _TaskNudgeVariant(
        index: 2,
        style: _TaskNudgeStyle.practical,
        title: 'Quick planning check-in',
        body: 'Capture your next task now so it is easier to start when ready.',
      ),
      _TaskNudgeVariant(
        index: 3,
        style: _TaskNudgeStyle.contextual,
        title: 'How about your next focus block?',
        body:
            'Add a task for this part of the day and give yourself a clear target.',
      ),
    ];

    final lastIndex = _settings.lastTaskNudgeVariantIndex;
    final candidates = variants.where((v) => v.index != lastIndex).toList();
    if (candidates.isEmpty) return variants.first;
    return candidates[_random.nextInt(candidates.length)];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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

  _TaskAndSlot? _findNextSlotAfter({
    required List<SignalTask> allTasks,
    required DateTime after,
    required String excludingSlotId,
  }) {
    _TaskAndSlot? next;

    for (final task in allTasks) {
      for (final slot in task.timeSlots) {
        if (slot.id == excludingSlotId ||
            slot.isDiscarded ||
            slot.isCompleted ||
            slot.hasStarted) {
          continue;
        }
        if (!slot.plannedStartTime.isAfter(after)) continue;

        if (next == null ||
            slot.plannedStartTime.isBefore(next.slot.plannedStartTime)) {
          next = _TaskAndSlot(task: task, slot: slot);
        }
      }
    }

    return next;
  }

  String _formatClockTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _flushPendingTimerAction() async {
    final pending = _pendingTimerAction;
    if (pending == null) return;

    switch (pending.actionId) {
      case 'continue':
        final handler = _onContinueActionRequested;
        if (handler == null) return;
        _pendingTimerAction = null;
        try {
          await handler(pending.taskId, pending.slotId);
        } catch (e, st) {
          debugPrint('[NotificationAction] continue failed: $e');
          debugPrint('$st');
        }
        return;
      case 'end':
        final handler = _onEndActionRequested;
        if (handler == null) return;
        _pendingTimerAction = null;
        try {
          await handler(pending.taskId, pending.slotId);
        } catch (e, st) {
          debugPrint('[NotificationAction] end failed: $e');
          debugPrint('$st');
        }
        return;
      default:
        _pendingTimerAction = null;
        return;
    }
  }

  /// Handle notification tap
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // Handle action buttons
    final actionId = response.actionId;
    final timerIds = _parseTimerPayload(response.payload);
    if (actionId != null) {
      switch (actionId) {
        case 'start':
          // TODO: Navigate to task and start timer
          break;
        case 'snooze':
          // TODO: Snooze notification by 5 minutes
          break;
        case 'continue':
          if (timerIds == null) break;
          final handler = _onContinueActionRequested;
          if (handler != null) {
            try {
              await handler(timerIds.taskId, timerIds.slotId);
            } catch (e, st) {
              debugPrint('[NotificationAction] continue failed: $e');
              debugPrint('$st');
            }
          } else {
            _pendingTimerAction = _PendingTimerAction(
              actionId: actionId,
              taskId: timerIds.taskId,
              slotId: timerIds.slotId,
            );
          }
          break;
        case 'end':
          if (timerIds == null) break;
          final handler = _onEndActionRequested;
          if (handler != null) {
            try {
              await handler(timerIds.taskId, timerIds.slotId);
            } catch (e, st) {
              debugPrint('[NotificationAction] end failed: $e');
              debugPrint('$st');
            }
          } else {
            _pendingTimerAction = _PendingTimerAction(
              actionId: actionId,
              taskId: timerIds.taskId,
              slotId: timerIds.slotId,
            );
          }
          break;
      }
    }
    // For now, just opening the app is sufficient
  }

  String _buildTimerPayload(String taskId, String slotId) {
    return '$taskId::$slotId';
  }

  _TimerPayload? _parseTimerPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split('::');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return null;
    }
    return _TimerPayload(taskId: parts[0], slotId: parts[1]);
  }

  /// Cancel all notifications and timers
  Future<void> cancelAll() async {
    _noiseCheckTimer?.cancel();
    _inactivityCheckTimer?.cancel();
    _taskNudgeCheckTimer?.cancel();
    await _notifications.cancelAll();
  }

  /// Dispose resources
  void dispose() {
    _noiseCheckTimer?.cancel();
    _inactivityCheckTimer?.cancel();
    _taskNudgeCheckTimer?.cancel();
  }
}

class _TaskAndSlot {
  final SignalTask task;
  final TimeSlot slot;

  const _TaskAndSlot({required this.task, required this.slot});
}

class _PendingTimerAction {
  final String actionId;
  final String taskId;
  final String slotId;

  const _PendingTimerAction({
    required this.actionId,
    required this.taskId,
    required this.slotId,
  });
}

class _TimerPayload {
  final String taskId;
  final String slotId;

  const _TimerPayload({required this.taskId, required this.slotId});
}

enum _TaskNudgeStyle { motivational, playful, practical, contextual }

class _TaskNudgeVariant {
  final int index;
  final _TaskNudgeStyle style;
  final String title;
  final String body;

  const _TaskNudgeVariant({
    required this.index,
    required this.style,
    required this.title,
    required this.body,
  });
}
