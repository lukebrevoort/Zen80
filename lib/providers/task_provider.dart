import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/daily_summary.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/live_activity_service.dart';

/// Manages task state and provides access to task operations
class TaskProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService();
  final LiveActivityService _liveActivityService = LiveActivityService();
  final Uuid _uuid = const Uuid();

  List<Task> _tasks = [];
  Timer? _uiUpdateTimer; // Timer just for UI updates, not for tracking time
  DateTime _selectedDate = DateTime.now();

  // Maximum signal tasks allowed per day
  static const int maxSignalTasks = 5;
  static const int minSignalTasks = 3;

  /// All tasks for the selected date
  List<Task> get tasks => _tasks;

  /// Signal tasks only
  List<Task> get signalTasks =>
      _tasks.where((t) => t.type == TaskType.signal).toList();

  /// Noise tasks only
  List<Task> get noiseTasks =>
      _tasks.where((t) => t.type == TaskType.noise).toList();

  /// Current selected date
  DateTime get selectedDate => _selectedDate;

  /// Task with active timer (finds it from storage, not memory)
  Task? get activeTimerTask {
    try {
      return _tasks.firstWhere((t) => t.isTimerRunning);
    } catch (_) {
      // Check all tasks in storage for any running timer
      final allTasks = _storage.getAllTasks();
      try {
        return allTasks.firstWhere((t) => t.isTimerRunning);
      } catch (_) {
        return null;
      }
    }
  }

  /// Whether a timer is currently running
  bool get isTimerRunning => activeTimerTask != null;

  /// Get today's summary
  DailySummary get todaySummary =>
      DailySummary(date: _selectedDate, tasks: _tasks);

  /// Whether we can add more signal tasks today
  bool get canAddSignalTask => signalTasks.length < maxSignalTasks;

  /// How many more signal tasks can be added
  int get remainingSignalSlots => maxSignalTasks - signalTasks.length;

  /// Load tasks from storage for selected date
  Future<void> loadTasks() async {
    _tasks = _storage.getTasksForDate(_selectedDate);

    // Check if there's an active timer and start UI updates
    final activeTask = activeTimerTask;
    if (activeTask != null) {
      _startUiUpdateTimer();
    }

    notifyListeners();
  }

  /// Called when app resumes from background - recalculates timer state
  Future<void> onAppResumed() async {
    await loadTasks();

    // If there's an active timer, update the live activity
    final activeTask = activeTimerTask;
    if (activeTask != null) {
      await _liveActivityService.updateTimerActivity(task: activeTask);
    }
  }

  /// Change selected date and load tasks for that date
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    await loadTasks();
  }

  /// Add a new task
  Future<void> addTask({required String title, required TaskType type}) async {
    // Enforce signal task limit
    if (type == TaskType.signal && !canAddSignalTask) {
      throw Exception('Maximum $maxSignalTasks signal tasks allowed per day');
    }

    final task = Task(
      id: _uuid.v4(),
      title: title,
      type: type,
      createdAt: DateTime.now(),
      date: _selectedDate,
    );

    await _storage.addTask(task);

    // Record activity for inactivity tracking
    await _notificationService.recordActivity();

    await loadTasks();
  }

  /// Update an existing task
  Future<void> updateTask(Task task) async {
    await _storage.updateTask(task);
    await loadTasks();
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    // Stop timer if deleting active task
    final activeTask = activeTimerTask;
    if (activeTask?.id == id) {
      await stopTimer();
    }

    await _storage.deleteTask(id);
    await loadTasks();
  }

  /// Toggle task completion status
  Future<void> toggleTaskComplete(String id) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];

      // If completing a task with active timer, stop the timer first
      if (!task.isCompleted && task.isTimerRunning) {
        await stopTimer();
      }

      final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
      await _storage.updateTask(updatedTask);
      await loadTasks();
    }
  }

  /// Start timer for a task
  Future<void> startTimer(Task task) async {
    // Stop any existing timer first
    await stopTimer();

    // Start the timer on the task
    task.startTimer();
    await _storage.updateTask(task);

    // Record activity for inactivity tracking
    await _notificationService.recordActivity();

    // Start Live Activity (shows in Dynamic Island / Lock Screen)
    await _liveActivityService.startTimerActivity(
      task: task,
      startedAt: task.timerStartedAt!,
    );

    // If it's a NOISE task, start monitoring for the 1-hour warning
    // Signal tasks get NO push notifications (reward for focus)
    if (task.type == TaskType.noise) {
      _notificationService.startNoiseTimerMonitoring(
        taskTitle: task.title,
        startedAt: task.timerStartedAt!,
      );
    } else {
      // For Signal tasks, just mark timer as active (for inactivity check)
      _notificationService.markTimerStarted();
    }

    // Start UI update timer (just for display, not for time tracking)
    _startUiUpdateTimer();

    await loadTasks();
  }

  /// Start a timer that updates the UI periodically
  void _startUiUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners(); // Trigger UI rebuild to show updated time
    });
  }

  /// Stop the current timer
  Future<void> stopTimer() async {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    final activeTask = activeTimerTask;
    if (activeTask != null) {
      // Stop the timer on the task (this adds elapsed time to timeSpentSeconds)
      activeTask.stopTimer();
      await _storage.updateTask(activeTask);

      // Record activity for inactivity tracking
      await _notificationService.recordActivity();

      // End the Live Activity
      await _liveActivityService.endTimerActivity();

      // Stop noise timer monitoring (if it was a noise task)
      // This also resets _isTimerActive for noise tasks
      _notificationService.stopNoiseTimerMonitoring();

      // Ensure timer is marked as stopped (for Signal tasks)
      _notificationService.markTimerStopped();

      // Check if we've achieved the golden ratio
      final summary = todaySummary;
      await _notificationService.checkGoldenRatioAchievement(
        signalPercentage: summary.signalPercentage,
        totalTime: summary.totalTime,
      );
    }

    await loadTasks();
    notifyListeners();
  }

  /// Add time manually to a task
  Future<void> addTimeToTask(String id, Duration duration) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      task.addTime(duration);
      await _storage.updateTask(task);

      // Record activity for inactivity tracking
      await _notificationService.recordActivity();

      // Check if we've achieved the golden ratio
      final summary = todaySummary;
      await _notificationService.checkGoldenRatioAchievement(
        signalPercentage: summary.signalPercentage,
        totalTime: summary.totalTime,
      );

      await loadTasks();
    }
  }

  /// Get summaries for the last 7 days
  List<DailySummary> getWeeklySummaries() {
    final allTasks = _storage.getTasksForLastWeek();
    final summaries = <DailySummary>[];

    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final dayTasks = allTasks
          .where(
            (t) =>
                t.date.year == normalizedDate.year &&
                t.date.month == normalizedDate.month &&
                t.date.day == normalizedDate.day,
          )
          .toList();

      summaries.add(DailySummary(date: normalizedDate, tasks: dayTasks));
    }

    return summaries;
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }
}
