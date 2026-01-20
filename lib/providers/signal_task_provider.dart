import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/google_calendar_service.dart';
import '../services/sync_service.dart';

/// Provider for managing Signal tasks (v2)
class SignalTaskProvider extends ChangeNotifier {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  List<SignalTask> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  SignalTask? _activeTask; // Task with running timer
  Timer? _autoEndTimer; // Timer for checking auto-end conditions
  DateTime? _lastMissedSlotCheck; // Throttle for missed slot cleanup
  DateTime? _lastOvertimeSync; // Throttle for overtime calendar sync

  /// Callback for when a task timer starts
  /// Can be used to update notifications and track actual work
  void Function(SignalTask task, TimeSlot slot)? onTimerStart;

  /// Callback for when a task timer stops
  /// Can be used to manage notification state
  void Function(SignalTask task, TimeSlot slot)? onTimerStop;

  /// Callback for when a task is auto-ended
  /// Can be used to show notifications or update UI
  void Function(SignalTask task, TimeSlot slot)? onAutoEnd;

  /// Callback for when a task timer reaches its planned end time
  /// Can be used to prompt the user to continue or end
  void Function(SignalTask task, TimeSlot slot)? onTimerReachedEnd;

  static const int maxSignalTasks = 5;
  static const int minSignalTasks = 3;

  SignalTaskProvider(this._storageService) {
    loadTasks();
    _startAutoEndChecker();
  }

  @override
  void dispose() {
    _autoEndTimer?.cancel();
    super.dispose();
  }

  /// Start a periodic timer to check for auto-end conditions
  void _startAutoEndChecker() {
    _autoEndTimer?.cancel();
    _autoEndTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAutoEnd();
    });
  }

  /// Check if any active timer should be auto-ended
  void _checkAutoEnd() {
    // Also check for missed slots (throttled to every 2 minutes)
    _checkMissedSlotsThrottled();

    if (_activeTask == null) return;

    final taskToEnd = _activeTask!;
    final activeSlot = taskToEnd.activeTimeSlot;
    if (activeSlot == null) return;

    // Prevent immediate auto-end for ad-hoc slots that start at "now".
    // When a slot is created with plannedEndTime ~= now + estimatedMinutes,
    // rapid periodic checks can still see isPastPlannedEnd as true if plannedEndTime
    // is already in the past (e.g., bad data / imported slot).
    // Only auto-end if we're meaningfully past the planned end.
    const grace = Duration(seconds: 15);
    final pastEndBy = DateTime.now().difference(activeSlot.plannedEndTime);

    // Check if we've passed the planned end time
    if (pastEndBy >= Duration.zero) {
      // If auto-end is enabled and user hasn't manually continued
      if (activeSlot.autoEnd &&
          !activeSlot.wasManualContinue &&
          pastEndBy >= grace) {
        // Auto-end the timer
        stopTimeSlot(taskToEnd.id, activeSlot.id);
        onAutoEnd?.call(taskToEnd, activeSlot);
      } else if (!activeSlot.wasManualContinue && pastEndBy >= grace) {
        // Notify that timer has reached end (for UI prompts)
        onTimerReachedEnd?.call(taskToEnd, activeSlot);
      }

      // Overtime calendar sync: When user is working past plannedEndTime,
      // periodically update the calendar event to show the growing overtime.
      // Throttled to every 2 minutes to avoid API spam.
      if (pastEndBy >= grace &&
          (activeSlot.wasManualContinue || !activeSlot.autoEnd)) {
        _checkOvertimeSyncThrottled(taskToEnd, activeSlot);
      }
    }
  }

  /// Throttled check for missed slots - runs at most every 2 minutes
  /// to avoid excessive API calls while still catching missed slots reasonably quickly
  void _checkMissedSlotsThrottled() {
    final now = DateTime.now();
    const throttleInterval = Duration(minutes: 2);

    // Skip if we checked recently
    if (_lastMissedSlotCheck != null &&
        now.difference(_lastMissedSlotCheck!) < throttleInterval) {
      return;
    }

    _lastMissedSlotCheck = now;

    // Run cleanup asynchronously (don't block the timer check)
    cleanupMissedSlots();
  }

  /// Throttled overtime sync - runs at most every 2 minutes
  /// to update calendar event when user is working past plannedEndTime.
  /// Per PLAN.md: "Update end time periodically (every 1-5 min)"
  void _checkOvertimeSyncThrottled(SignalTask task, TimeSlot slot) {
    final now = DateTime.now();
    const throttleInterval = Duration(minutes: 2);

    // Skip if we synced recently
    if (_lastOvertimeSync != null &&
        now.difference(_lastOvertimeSync!) < throttleInterval) {
      return;
    }

    // Only sync if slot has a calendar event
    if (slot.googleCalendarEventId == null &&
        slot.externalCalendarEventId == null) {
      return;
    }

    _lastOvertimeSync = now;

    // Run overtime sync asynchronously
    _syncSlotToCalendarOvertime(task, slot);
  }

  // ============ Getters ============

  /// All tasks for the selected date
  List<SignalTask> get tasks => List.unmodifiable(_tasks);

  /// Currently selected date
  DateTime get selectedDate => _selectedDate;

  /// Task with active timer (if any)
  SignalTask? get activeTask => _activeTask;

  /// Whether any task has an active timer
  bool get hasActiveTimer => _activeTask != null;

  /// Number of tasks for the selected date
  int get taskCount => _tasks.length;

  /// Whether we can add more tasks (max 5)
  bool get canAddTask => _tasks.length < maxSignalTasks;

  /// Whether we have minimum required tasks (3)
  bool get hasMinimumTasks => _tasks.length >= minSignalTasks;

  /// Tasks that are not yet complete
  List<SignalTask> get incompleteTasks =>
      _tasks.where((t) => !t.isComplete).toList();

  /// Tasks that are complete
  List<SignalTask> get completedTasks =>
      _tasks.where((t) => t.isComplete).toList();

  /// Tasks that appear on the calendar (have any non-discarded slots).
  /// This includes tasks with completed work, even if not "fully scheduled"
  /// by duration - fixing the bug where completed slots would disappear.
  List<SignalTask> get scheduledTasks =>
      _tasks.where((t) => t.hasCalendarPresence).toList();

  /// Tasks that need user to schedule time.
  /// A task needs scheduling only if it has no slots OR has no completed work
  /// and still has unscheduled estimated time.
  List<SignalTask> get unscheduledTasks =>
      _tasks.where((t) => t.needsScheduling).toList();

  /// Tasks that are partially scheduled (have some but not all time scheduled)
  List<SignalTask> get partiallyScheduledTasks =>
      _tasks.where((t) => t.isPartiallyScheduled).toList();

  /// Total estimated minutes for all tasks today
  int get totalEstimatedMinutes =>
      _tasks.fold(0, (sum, t) => sum + t.estimatedMinutes);

  /// Total actual minutes worked today
  int get totalActualMinutes =>
      _tasks.fold(0, (sum, t) => sum + t.actualMinutes);

  /// Completion percentage for the day
  double get dayCompletionPercentage {
    if (totalEstimatedMinutes == 0) return 0;
    return (totalActualMinutes / totalEstimatedMinutes).clamp(0.0, 1.0);
  }

  // ============ Load/Refresh ============

  /// Load tasks for the selected date
  Future<void> loadTasks() async {
    _tasks = _storageService.getSignalTasksForDate(_selectedDate);
    _updateActiveTask();
    notifyListeners();
  }

  /// Refresh tasks from storage
  Future<void> refresh() async {
    await loadTasks();
  }

  /// Change the selected date and load tasks for that date
  Future<void> selectDate(DateTime date) async {
    _selectedDate = _normalizeDate(date);
    await loadTasks();
  }

  // ============ Task CRUD ============

  /// Create a new Signal task
  Future<SignalTask> createTask({
    required String title,
    required int estimatedMinutes,
    List<String>? tagIds,
    List<SubTask>? subTasks,
    DateTime? scheduledDate,
  }) async {
    final task = SignalTask(
      id: _uuid.v4(),
      title: title.trim(),
      estimatedMinutes: estimatedMinutes,
      tagIds: tagIds ?? [],
      subTasks: subTasks ?? [],
      status: TaskStatus.notStarted,
      scheduledDate: scheduledDate ?? _selectedDate,
      timeSlots: [],
      isComplete: false,
      createdAt: DateTime.now(),
    );

    await _storageService.addSignalTask(task);

    // Add to local list if it's for the selected date
    if (_isSameDay(task.scheduledDate, _selectedDate)) {
      _tasks.add(task);
      notifyListeners();
    }

    return task;
  }

  /// Add a pre-built task (e.g., from Google Calendar import)
  Future<void> addSignalTask(SignalTask task) async {
    await _storageService.addSignalTask(task);

    // Add to local list if it's for the selected date
    if (_isSameDay(task.scheduledDate, _selectedDate)) {
      _tasks.add(task);
      notifyListeners();
    }
  }

  /// Update an existing task
  Future<void> updateTask(SignalTask task) async {
    await _storageService.updateSignalTask(task);

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      _updateActiveTask();
      notifyListeners();
    }
  }

  /// Delete a task
  /// Also deletes any Google Calendar events associated with the task's time slots
  Future<void> deleteTask(String taskId) async {
    // Get the task before deleting to access its time slots
    final task = getTask(taskId);

    // Delete Google Calendar events for all time slots that have them
    // Note: We only delete Signal-created events (googleCalendarEventId), NOT imported
    // external events (externalCalendarEventId). Imported events existed before Signal
    // linked to them, so deleting the task just un-links - it doesn't delete the original.
    if (task != null && GoogleCalendarService().isConnected) {
      for (final slot in task.timeSlots) {
        if (slot.googleCalendarEventId != null) {
          await SyncService().queueDeleteEvent(
            taskId: taskId,
            timeSlotId: slot.id,
            googleCalendarEventId: slot.googleCalendarEventId!,
          );
        }
      }
    }

    await _storageService.deleteSignalTask(taskId);
    _tasks.removeWhere((t) => t.id == taskId);

    if (_activeTask?.id == taskId) {
      _activeTask = null;
    }

    notifyListeners();
  }

  /// Get a task by ID
  SignalTask? getTask(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return _storageService.getSignalTask(id);
    }
  }

  // ============ Task Status ============

  /// Mark a task as complete
  Future<void> completeTask(String taskId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.markComplete();
    await updateTask(task);
  }

  /// Mark a task as incomplete
  Future<void> uncompleteTask(String taskId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.isComplete = false;
    task.status = task.actualMinutes > 0
        ? TaskStatus.inProgress
        : TaskStatus.notStarted;
    await updateTask(task);
  }

  /// Toggle task completion
  Future<void> toggleTaskComplete(String taskId) async {
    final task = getTask(taskId);
    if (task == null) return;

    if (task.isComplete) {
      await uncompleteTask(taskId);
    } else {
      await completeTask(taskId);
    }
  }

  // ============ Sub-tasks ============

  /// Add a sub-task to a task
  Future<void> addSubTask(String taskId, String subTaskTitle) async {
    final task = getTask(taskId);
    if (task == null) return;

    final subTask = SubTask(
      id: _uuid.v4(),
      title: subTaskTitle.trim(),
      isChecked: false,
    );

    task.addSubTask(subTask);
    await updateTask(task);
  }

  /// Remove a sub-task from a task
  Future<void> removeSubTask(String taskId, String subTaskId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.removeSubTask(subTaskId);
    await updateTask(task);
  }

  /// Toggle a sub-task's checked state
  Future<void> toggleSubTask(String taskId, String subTaskId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.toggleSubTask(subTaskId);
    await updateTask(task);
  }

  /// Update a sub-task's title
  Future<void> updateSubTaskTitle(
    String taskId,
    String subTaskId,
    String newTitle,
  ) async {
    final task = getTask(taskId);
    if (task == null) return;

    final subTask = task.subTasks.firstWhere((st) => st.id == subTaskId);
    final updatedSubTask = subTask.copyWith(title: newTitle.trim());

    final index = task.subTasks.indexWhere((st) => st.id == subTaskId);
    task.subTasks[index] = updatedSubTask;

    await updateTask(task);
  }

  // ============ Tags ============

  /// Add a tag to a task
  Future<void> addTagToTask(String taskId, String tagId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.addTag(tagId);
    await updateTask(task);
  }

  /// Remove a tag from a task
  Future<void> removeTagFromTask(String taskId, String tagId) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.removeTag(tagId);
    await updateTask(task);
  }

  // ============ Time Slots ============

  /// Add a time slot to a task (with TimeSlot object)
  ///
  /// **IMPORTANT: Calendar sync is NOT triggered here!**
  /// Calendar events are only created AFTER the commitment threshold is met
  /// (5 min for short tasks, 10 min for 2+ hour tasks) to prevent polluting
  /// the user's calendar with tasks they start for 3 seconds and abandon.
  ///
  /// Calendar sync happens in `_syncSlotToCalendar` after `stopTimeSlot` confirms
  /// the session met the threshold.
  Future<void> addTimeSlotToTask(String taskId, TimeSlot slot) async {
    final task = getTask(taskId);
    if (task == null) return;

    task.addTimeSlot(slot);
    await updateTask(task);

    // NOTE: We intentionally do NOT create a calendar event here.
    // Calendar events are created only after the commitment threshold is met
    // in stopTimeSlot -> _syncSlotToCalendar. This prevents:
    // 1. Users scheduling but never starting
    // 2. Users starting for 3 seconds then stopping
    // 3. Cluttering the calendar with abandoned sessions
  }

  /// Add a time slot to a task
  ///
  /// **IMPORTANT: Calendar sync is NOT triggered here!**
  /// See `addTimeSlotToTask(String, TimeSlot)` for explanation.
  Future<void> addTimeSlot(
    String taskId, {
    required DateTime startTime,
    required DateTime endTime,
    List<String>? linkedSubTaskIds,
  }) async {
    final task = getTask(taskId);
    if (task == null) return;

    final slot = TimeSlot(
      id: _uuid.v4(),
      plannedStartTime: startTime,
      plannedEndTime: endTime,
      linkedSubTaskIds: linkedSubTaskIds ?? [],
    );

    task.addTimeSlot(slot);
    await updateTask(task);

    // NOTE: We intentionally do NOT create a calendar event here.
    // Calendar events are created only after the commitment threshold is met.
  }

  /// Remove a time slot from a task
  Future<void> removeTimeSlot(String taskId, String slotId) async {
    final task = getTask(taskId);
    if (task == null) return;

    // Get the slot before removing to check for calendar event
    final slot = task.timeSlots.cast<TimeSlot?>().firstWhere(
      (s) => s?.id == slotId,
      orElse: () => null,
    );

    // Queue calendar delete if connected and slot has a Signal-created calendar event
    // Note: We only delete Signal-created events (googleCalendarEventId), NOT imported
    // external events (externalCalendarEventId). Imported events existed before Signal
    // linked to them, so removing the slot just un-links - it doesn't delete the original.
    if (slot != null &&
        slot.googleCalendarEventId != null &&
        GoogleCalendarService().isConnected) {
      await SyncService().queueDeleteEvent(
        taskId: taskId,
        timeSlotId: slotId,
        googleCalendarEventId: slot.googleCalendarEventId!,
      );
    }

    task.removeTimeSlot(slotId);
    await updateTask(task);
  }

  /// Update a time slot's times
  Future<void> updateTimeSlot(
    String taskId,
    String slotId, {
    DateTime? startTime,
    DateTime? endTime,
    bool? autoEnd,
  }) async {
    final task = getTask(taskId);
    if (task == null) return;

    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = task.timeSlots[slotIndex];
    final updatedSlot = slot.copyWith(
      plannedStartTime: startTime,
      plannedEndTime: endTime,
      autoEnd: autoEnd,
    );
    task.timeSlots[slotIndex] = updatedSlot;

    await updateTask(task);

    // Queue calendar update if connected and slot has a calendar event
    // Check both Signal-created events (googleCalendarEventId) and imported events (externalCalendarEventId)
    if (GoogleCalendarService().isConnected) {
      final calendarEventId =
          slot.googleCalendarEventId ?? slot.externalCalendarEventId;
      if (calendarEventId != null) {
        await SyncService().queueUpdateEvent(
          task: task,
          slot: updatedSlot,
          googleCalendarEventId: calendarEventId,
        );
      }
    }
  }

  // ============ Timer Management ============

  /// Session merge threshold - gaps less than this are merged into one session
  static const Duration sessionMergeThreshold = Duration(minutes: 15);

  /// Commitment threshold for short tasks (< 2 hours)
  static const Duration shortTaskCommitmentThreshold = Duration(minutes: 5);

  /// Commitment threshold for long tasks (>= 2 hours)
  static const Duration longTaskCommitmentThreshold = Duration(minutes: 10);

  /// Start the timer for a time slot
  /// Handles session merging: gaps < 15 min continue same slot, gaps >= 15 min create new slot
  Future<void> startTimeSlot(String taskId, String slotId) async {
    // Stop any currently running timer first
    if (_activeTask != null) {
      await stopActiveTimer();
    }

    final task = getTask(taskId);
    if (task == null) return;

    task.startTimeSlot(slotId);
    await updateTask(task);

    // Ensure _activeTask points at the in-memory instance in _tasks.
    final updatedIndex = _tasks.indexWhere((t) => t.id == taskId);
    _activeTask = updatedIndex != -1 ? _tasks[updatedIndex] : null;

    // Sync calendar event on start (if slot has a calendar event from "Start My Day")
    // This updates the event's start time to actualStartTime
    final startedSlot = _activeTask?.timeSlots.cast<TimeSlot?>().firstWhere(
      (s) => s?.id == slotId,
      orElse: () => null,
    );
    if (_activeTask != null &&
        startedSlot != null &&
        (startedSlot.googleCalendarEventId != null ||
            startedSlot.externalCalendarEventId != null)) {
      await _syncSlotToCalendarOnStart(_activeTask!, startedSlot);
    }

    // Call timer start callback for notification management
    if (_activeTask != null && startedSlot != null) {
      onTimerStart?.call(_activeTask!, startedSlot);
    }
  }

  /// Result of a smart start operation, including early start info for nudge display
  static const String _earlyStartKey = 'isEarlyStart';
  static const String _slotIdKey = 'slotId';
  static const String _startTimeKey = 'startTime';

  /// Smart start: Determines whether to resume existing slot or create new one based on gap
  /// Returns a map containing:
  /// - 'slotId': The slot ID that was started (either existing or newly created)
  /// - 'isEarlyStart': Whether this start is before the user's configured focus time
  /// - 'startTime': The actual start time (for extending focus window)
  Future<Map<String, dynamic>> smartStartTask(
    String taskId, {
    TimeSlot? preferredSlot,
  }) async {
    // Stop any currently running timer first
    if (_activeTask != null) {
      await stopActiveTimer();
    }

    final task = getTask(taskId);
    if (task == null) throw Exception('Task not found');

    final now = DateTime.now();

    // Check if we should resume an existing slot (gap < 15 min)
    final lastSlot = task.lastStoppedSlot;

    if (lastSlot != null && lastSlot.canMergeSession) {
      // Gap is less than 15 minutes - resume the existing slot

      // IMPORTANT: If the slot's plannedEndTime is in the past, extend it
      // to prevent the auto-end checker from immediately stopping the timer.
      // This happens when user resumes after the original planned end time.
      final slotIndex = task.timeSlots.indexWhere((s) => s.id == lastSlot.id);
      if (slotIndex != -1 && lastSlot.plannedEndTime.isBefore(now)) {
        // Extend plannedEndTime to now + remaining estimated time (min 30 min)
        final remainingMinutes = task.remainingMinutes > 0
            ? task.remainingMinutes
            : 30;
        final newPlannedEnd = now.add(Duration(minutes: remainingMinutes));
        task.timeSlots[slotIndex] = lastSlot.copyWith(
          plannedEndTime: newPlannedEnd,
          wasManualContinue:
              true, // Mark as manual continue since past original end
        );
      }

      task.startTimeSlot(lastSlot.id);
      await updateTask(task);

      // Point _activeTask at updated in-memory task, not a possibly-stale re-fetch.
      final updatedIndex = _tasks.indexWhere((t) => t.id == taskId);
      _activeTask = updatedIndex != -1 ? _tasks[updatedIndex] : null;

      // If this session already has a calendar event, update its span on resume.
      final resumedTask = _activeTask;
      final resumedSlot = resumedTask?.timeSlots.cast<TimeSlot?>().firstWhere(
        (s) => s?.id == lastSlot.id,
        orElse: () => null,
      );
      if (resumedTask != null &&
          resumedSlot != null &&
          (resumedSlot.googleCalendarEventId != null ||
              resumedSlot.externalCalendarEventId != null)) {
        await _syncSlotToCalendar(resumedTask, resumedSlot);
      }

      // Resume is never an "early start" - we already started this session earlier
      // Call timer start callback for notification management
      if (resumedTask != null && resumedSlot != null) {
        onTimerStart?.call(resumedTask, resumedSlot);
      }

      return {
        _slotIdKey: lastSlot.id,
        _earlyStartKey: false,
        _startTimeKey: now,
      };
    }

    // Gap >= 15 min OR no previous slot - need to use/create a slot
    String slotIdToStart;

    if (preferredSlot != null) {
      // A preferred slot from the UI is only a *suggestion*.
      // We still must respect the 30-minute proximity rule so we don't hijack
      // a far-future scheduled slot when the user starts early.
      const slotProximityThreshold = Duration(minutes: 30);
      final timeUntilPreferred = preferredSlot.plannedStartTime.difference(now);
      final preferredIsCloseEnough =
          timeUntilPreferred.abs() <= slotProximityThreshold;

      if (!preferredSlot.hasStarted && preferredIsCloseEnough) {
        // Use the preferred scheduled slot - it's close enough in time
        slotIdToStart = preferredSlot.id;
      } else {
        // Preferred slot is either already used OR too far away -> create ad-hoc.
        final remainingTime = task.remainingMinutes > 0
            ? task.remainingMinutes
            : task.estimatedMinutes;
        final newSlot = TimeSlot(
          id: _uuid.v4(),
          plannedStartTime: now,
          plannedEndTime: now.add(Duration(minutes: remainingTime)),
          linkedSubTaskIds: preferredSlot.linkedSubTaskIds,
        );
        task.addTimeSlot(newSlot);
        slotIdToStart = newSlot.id;
      }
    } else if (task.timeSlots.isEmpty) {
      // No slots exist, create ad-hoc slot
      final newSlot = TimeSlot(
        id: _uuid.v4(),
        plannedStartTime: now,
        plannedEndTime: now.add(Duration(minutes: task.estimatedMinutes)),
      );
      task.addTimeSlot(newSlot);
      slotIdToStart = newSlot.id;
    } else {
      // Find the best slot to use, respecting the 30-minute threshold.
      // If we're starting more than 30 minutes before the nearest scheduled slot,
      // create an ad-hoc slot instead of hijacking the scheduled one.
      final unusedSlots = task.timeSlots
          .where((s) => !s.hasStarted && !s.isDiscarded)
          .toList();

      // Threshold: Only use a scheduled slot if it starts within 30 minutes
      const slotProximityThreshold = Duration(minutes: 30);

      if (unusedSlots.isNotEmpty) {
        // Sort by proximity to now
        unusedSlots.sort((a, b) {
          final aDiff = a.plannedStartTime.difference(now).abs();
          final bDiff = b.plannedStartTime.difference(now).abs();
          return aDiff.compareTo(bDiff);
        });

        final nearestSlot = unusedSlots.first;
        final timeUntilSlot = nearestSlot.plannedStartTime.difference(now);

        // Check if the nearest slot is within the proximity threshold.
        // We use the slot if:
        // 1. It's in the past (we're late, but close enough)
        // 2. It starts within 30 minutes from now
        // Note: For past slots, we check if we're within 30 min AFTER the planned start
        final isCloseEnough = timeUntilSlot.abs() <= slotProximityThreshold;

        if (isCloseEnough) {
          // Use the scheduled slot - it's close enough in time
          slotIdToStart = nearestSlot.id;
        } else {
          // Too far from any scheduled slot - create an ad-hoc slot
          // This preserves the scheduled slots for their intended times
          final remainingTime = task.remainingMinutes > 0
              ? task.remainingMinutes
              : task.estimatedMinutes;
          final newSlot = TimeSlot(
            id: _uuid.v4(),
            plannedStartTime: now,
            plannedEndTime: now.add(Duration(minutes: remainingTime)),
          );
          task.addTimeSlot(newSlot);
          slotIdToStart = newSlot.id;
        }
      } else {
        // All slots have been used - create a new one for this session
        final remainingTime = task.remainingMinutes > 0
            ? task.remainingMinutes
            : 60;
        final newSlot = TimeSlot(
          id: _uuid.v4(),
          plannedStartTime: now,
          plannedEndTime: now.add(Duration(minutes: remainingTime)),
        );
        task.addTimeSlot(newSlot);
        slotIdToStart = newSlot.id;
      }
    }

    task.startTimeSlot(slotIdToStart);
    await updateTask(task);

    final updatedIndex = _tasks.indexWhere((t) => t.id == taskId);
    _activeTask = updatedIndex != -1 ? _tasks[updatedIndex] : null;

    // Sync calendar event on initial start (if slot has a calendar event from "Start My Day")
    // This updates the event's start time to actualStartTime
    final startedTask = _activeTask;
    final startedSlot = startedTask?.timeSlots.cast<TimeSlot?>().firstWhere(
      (s) => s?.id == slotIdToStart,
      orElse: () => null,
    );
    if (startedTask != null &&
        startedSlot != null &&
        (startedSlot.googleCalendarEventId != null ||
            startedSlot.externalCalendarEventId != null)) {
      await _syncSlotToCalendarOnStart(startedTask, startedSlot);
    }

    // Call timer start callback for notification management
    if (startedTask != null && startedSlot != null) {
      onTimerStart?.call(startedTask, startedSlot);
    }

    // Return result with early start info for the UI to handle nudges
    return {
      _slotIdKey: slotIdToStart,
      // Provider doesn't know user's settings; caller should compute this via SettingsProvider.
      _earlyStartKey: false,
      _startTimeKey: now,
    };
  }

  /// Stop the timer for a time slot
  /// Handles commitment threshold: sessions < 5 min (or < 10 min for 2+ hour tasks) are discarded
  /// Stop the timer for a time slot.
  ///
  /// The session is discarded (and the slot reset) if it does not meet the
  /// commitment threshold, unless [forceKeep] is true.
  Future<void> stopTimeSlot(
    String taskId,
    String slotId, {
    bool forceKeep = false,
  }) async {
    final task = getTask(taskId);
    if (task == null) return;

    // Get the slot BEFORE ending to check session duration
    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = task.timeSlots[slotIndex];

    // Calculate current session work time (what would be accumulated on end)
    Duration currentSessionWork = Duration.zero;
    if (slot.actualStartTime != null && slot.isActive) {
      currentSessionWork = DateTime.now().difference(slot.actualStartTime!);
    }
    final totalWorkTime =
        Duration(seconds: slot.accumulatedSeconds) + currentSessionWork;

    // Determine commitment threshold based on task duration
    final commitmentThreshold = task.estimatedMinutes >= 120
        ? longTaskCommitmentThreshold
        : shortTaskCommitmentThreshold;

    // Check if this session meets the commitment threshold
    final meetsThreshold = totalWorkTime >= commitmentThreshold || forceKeep;

    // Per PLAN.md: Commitment threshold only applies to AD-HOC sessions.
    // Pre-scheduled slots (from "Start My Day") should NOT be discarded.
    // A slot is "pre-scheduled" if it has a calendar event from the planning phase.
    final isPreScheduledSlot =
        slot.googleCalendarEventId != null ||
        slot.externalCalendarEventId != null;

    if (!meetsThreshold && !isPreScheduledSlot) {
      // AD-HOC session didn't meet threshold - discard it.
      // This prevents calendar pollution from abandoned ad-hoc sessions.

      // Reset the slot to its pre-started state and mark as discarded
      final discardedSlot = slot.copyWith(
        isActive: false,
        clearActualStartTime: true,
        clearActualEndTime: true,
        clearSessionStartTime: true,
        clearLastStopTime: true,
        accumulatedSeconds: 0,
        hasSyncedToCalendar: false,
        isDiscarded: true,
        clearGoogleCalendarEventId: true,
      );
      task.timeSlots[slotIndex] = discardedSlot;

      if (_activeTask?.id == taskId) {
        _activeTask = null;
      }

      // Clean up notification state BEFORE discarding the session
      // This ensures _isTimerActive is reset and stale notifications are cancelled
      onTimerStop?.call(task, slot);

      await updateTask(task);
      // No calendar sync for discarded ad-hoc sessions
      return;
    }

    if (!meetsThreshold && isPreScheduledSlot) {
      // PRE-SCHEDULED slot didn't meet threshold - reset session but KEEP the slot.
      // Per PLAN.md: "Does NOT apply to pre-scheduled slots (they already have
      // calendar events from 'Start My Day')"
      //
      // The user intentionally scheduled this time, so we:
      // 1. Reset the session data (so they can try again)
      // 2. Keep the calendar event intact
      // 3. Keep isDiscarded = false (slot stays visible/scheduled)

      final resetSlot = slot.copyWith(
        isActive: false,
        clearActualStartTime: true,
        clearActualEndTime: true,
        clearSessionStartTime: true,
        clearLastStopTime: true,
        accumulatedSeconds: 0,
        isDiscarded: false, // KEEP the slot scheduled!
        // Do NOT clear googleCalendarEventId - keep the calendar event
      );
      task.timeSlots[slotIndex] = resetSlot;

      if (_activeTask?.id == taskId) {
        _activeTask = null;
      }

      // Clean up notification state BEFORE resetting the session
      // This ensures _isTimerActive is reset and stale notifications are cancelled
      onTimerStop?.call(task, slot);

      await updateTask(task);
      // No calendar sync needed - event stays as-is with planned times
      return;
    }

    // Session meets threshold - proceed with normal end
    task.endTimeSlot(slotId);

    // Get the updated slot after ending
    final updatedSlot = task.timeSlots.cast<TimeSlot?>().firstWhere(
      (s) => s?.id == slotId,
      orElse: () => null,
    );

    if (_activeTask?.id == taskId) {
      _activeTask = null;
    }

    await updateTask(task);

    // Queue calendar sync ONLY if session met threshold and slot isn't already synced
    if (updatedSlot != null && GoogleCalendarService().isConnected) {
      await _syncSlotToCalendar(task, updatedSlot);
    }

    // Call timer stop callback for notification management
    if (updatedSlot != null) {
      onTimerStop?.call(task, updatedSlot);
    }
  }

  /// Sync a slot to calendar (create or update event)
  /// Uses sessionStartTime -> actualEndTime for the calendar event span
  Future<void> _syncSlotToCalendar(SignalTask task, TimeSlot slot) async {
    // Only sync when we have real session data.
    // Calendar events should reflect *actual* sessions, not planned blocks.
    if (slot.sessionStartTime == null || slot.actualEndTime == null) {
      return;
    }

    // Determine the calendar event times
    // Use sessionStartTime for start (captures full session span including merged gaps)
    // Use actualEndTime for end
    final eventStartTime = slot.sessionStartTime!;
    final eventEndTime = slot.actualEndTime!;

    // IMPORTANT:
    // Do NOT mutate the slot's plannedStartTime/plannedEndTime here.
    // Those represent the user's schedule (planning). If we overwrite them
    // with the actual session span, the scheduling UI can wrongly decide the
    // task is no longer "fully scheduled" (scheduledMinutes shrinks), which
    // makes the task appear in the "unscheduled" list and its calendar block
    // disappear until the user "reschedules".
    //
    // For calendar sync we instead create/update the Google event with the
    // actual session timestamps while keeping the stored planned times intact.
    // Create a transient copy for syncing.
    // We reuse plannedStartTime/plannedEndTime fields as the payload for the
    // calendar event span, but we do *not* write this back to the task.
    final slotForSync = slot.copyWith(
      plannedStartTime: eventStartTime,
      plannedEndTime: eventEndTime,
    );

    final existingEventId =
        slot.googleCalendarEventId ?? slot.externalCalendarEventId;

    if (existingEventId != null) {
      // Update existing calendar event
      await SyncService().queueUpdateEvent(
        task: task,
        slot: slotForSync,
        googleCalendarEventId: existingEventId,
      );
    } else if (!slot.isImportedFromExternal && !slot.hasSyncedToCalendar) {
      // Mark as synced BEFORE queuing creation to prevent duplicates.
      final slotIndex = task.timeSlots.indexWhere((s) => s.id == slot.id);
      if (slotIndex != -1) {
        task.timeSlots[slotIndex] = slot.copyWith(hasSyncedToCalendar: true);
        await updateTask(task);
      }

      // Create new calendar event (only for Signal-created slots)
      // Pass the first tag's color for proper Google Calendar color mapping
      final tagColorHex = task.tagIds.isNotEmpty
          ? _storageService.getTag(task.tagIds.first)?.colorHex
          : null;
      await SyncService().queueCreateEvent(
        task: task,
        slot: slotForSync,
        colorHex: tagColorHex,
      );
    }
  }

  /// Sync a slot to calendar when the timer STARTS.
  /// This updates an existing calendar event (from "Start My Day") to show:
  /// - Start time: actualStartTime (when user actually started)
  /// - End time: plannedEndTime (still the planned end, will update during overtime)
  ///
  /// Per PLAN.md Phase 2: "On timer start: Update event start to actualStartTime"
  Future<void> _syncSlotToCalendarOnStart(
    SignalTask task,
    TimeSlot slot,
  ) async {
    // Only sync if connected
    if (!GoogleCalendarService().isConnected) return;

    // Must have a session start time (set when timer starts)
    if (slot.sessionStartTime == null) return;

    final existingEventId =
        slot.googleCalendarEventId ?? slot.externalCalendarEventId;
    if (existingEventId == null) return;

    // Create a transient copy with:
    // - Start: actualStartTime (when user actually started this session)
    // - End: plannedEndTime (still planned, will be updated when stopping or in overtime)
    final slotForSync = slot.copyWith(
      plannedStartTime: slot.sessionStartTime!,
      plannedEndTime: slot.plannedEndTime,
    );

    await SyncService().queueUpdateEvent(
      task: task,
      slot: slotForSync,
      googleCalendarEventId: existingEventId,
    );
  }

  /// Sync a slot to calendar during OVERTIME (working past plannedEndTime).
  /// Updates the calendar event to show:
  /// - Start time: sessionStartTime
  /// - End time: now (growing as user continues working)
  ///
  /// Per PLAN.md Phase 2: "On crossing plannedEndTime while active: Switch to overtime mode"
  /// and "Update end time periodically (every 1-5 min)"
  Future<void> _syncSlotToCalendarOvertime(
    SignalTask task,
    TimeSlot slot,
  ) async {
    // Only sync if connected
    if (!GoogleCalendarService().isConnected) return;

    // Must have a session start time
    if (slot.sessionStartTime == null) return;

    final existingEventId =
        slot.googleCalendarEventId ?? slot.externalCalendarEventId;
    if (existingEventId == null) return;

    // Create a transient copy with:
    // - Start: sessionStartTime
    // - End: now (growing overtime indicator)
    final slotForSync = slot.copyWith(
      plannedStartTime: slot.sessionStartTime!,
      plannedEndTime: DateTime.now(),
    );

    await SyncService().queueUpdateEvent(
      task: task,
      slot: slotForSync,
      googleCalendarEventId: existingEventId,
    );
  }

  /// Stop the currently active timer
  Future<void> stopActiveTimer({bool forceKeep = false}) async {
    if (_activeTask == null) return;

    final activeSlot = _activeTask!.activeTimeSlot;
    if (activeSlot != null) {
      await stopTimeSlot(_activeTask!.id, activeSlot.id, forceKeep: forceKeep);
    }
  }

  /// Continue a time slot past its planned end time
  Future<void> continueTimeSlot(String taskId, String slotId) async {
    final task = getTask(taskId);
    if (task == null) return;

    final slot = task.timeSlots.firstWhere((s) => s.id == slotId);
    slot.continueTimer();
    await updateTask(task);
  }

  // ============ History ============

  /// Get tasks for a specific date
  List<SignalTask> getTasksForDate(DateTime date) {
    return _storageService.getSignalTasksForDate(date);
  }

  /// Get tasks for the last 7 days
  List<SignalTask> getTasksForLastWeek() {
    return _storageService.getSignalTasksForLastWeek();
  }

  /// Get tasks for a specific date range
  List<SignalTask> getTasksForDateRange(DateTime start, DateTime end) {
    return _storageService.getSignalTasksForDateRange(start, end);
  }

  // ============ Private Helpers ============

  /// Update the active task reference
  void _updateActiveTask() {
    _activeTask = _tasks.cast<SignalTask?>().firstWhere(
      (t) => t?.hasActiveTimeSlot ?? false,
      orElse: () => null,
    );
  }

  /// Normalize date to midnight
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Called when app resumes from background
  void onAppResumed() {
    // Recalculate timer state
    _updateActiveTask();

    // Check for and clean up any missed slots
    // This catches slots that became "missed" while app was in background
    cleanupMissedSlots();

    notifyListeners();
  }

  // ============ Phase 6.B: Missed Slot Detection ============

  /// Get all missed time slots for a specific task
  /// A missed slot is one where planned end time has passed but never started
  List<TimeSlot> getMissedTimeSlots(SignalTask task) {
    return task.timeSlots.where((slot) {
      return slot.displayStatus == TimeSlotStatus.missed;
    }).toList();
  }

  /// Get all tasks with missed time slots for the selected date
  List<SignalTask> get tasksWithMissedSlots {
    return _tasks.where((task) {
      return getMissedTimeSlots(task).isNotEmpty;
    }).toList();
  }

  /// Get total count of missed slots today
  int get missedSlotCount {
    return _tasks.fold<int>(
      0,
      (sum, task) => sum + getMissedTimeSlots(task).length,
    );
  }

  /// Check if there are any missed slots that need attention
  bool get hasMissedSlots => missedSlotCount > 0;

  /// Reschedule a missed slot to a new time
  Future<void> rescheduleMissedSlot(
    String taskId,
    String slotId, {
    required DateTime newStartTime,
    Duration? newDuration,
  }) async {
    final task = getTask(taskId);
    if (task == null) return;

    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = task.timeSlots[slotIndex];

    // Use existing duration if not specified
    final duration = newDuration ?? slot.plannedDuration;
    final newEndTime = newStartTime.add(duration);

    // Create updated slot with new times (reset all session data)
    final updatedSlot = slot.copyWith(
      plannedStartTime: newStartTime,
      plannedEndTime: newEndTime,
      clearActualStartTime: true,
      clearActualEndTime: true,
      clearSessionStartTime: true,
      clearLastStopTime: true,
      accumulatedSeconds: 0,
      isDiscarded: false,
      hasSyncedToCalendar: false,
    );

    task.timeSlots[slotIndex] = updatedSlot;
    await updateTask(task);
  }

  /// Discard a missed slot (user chose not to do it)
  Future<void> discardMissedSlot(String taskId, String slotId) async {
    final task = getTask(taskId);
    if (task == null) return;

    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = task.timeSlots[slotIndex];

    // Mark as discarded
    task.timeSlots[slotIndex] = slot.copyWith(isDiscarded: true);

    await updateTask(task);
  }

  /// Get slots grouped by status for a task
  Map<TimeSlotStatus, List<TimeSlot>> getSlotsByStatus(SignalTask task) {
    final grouped = <TimeSlotStatus, List<TimeSlot>>{};

    for (final status in TimeSlotStatus.values) {
      grouped[status] = task.timeSlots
          .where((slot) => slot.displayStatus == status)
          .toList();
    }

    return grouped;
  }

  /// Check for missed slots and notify (called periodically or on app resume)
  void checkForMissedSlots() {
    // This would be called by the auto-end checker or on app resume
    // to detect newly missed slots and trigger UI updates
    if (hasMissedSlots) {
      notifyListeners();
    }
  }

  // ============ Phase: Missed Slot Calendar Cleanup ============

  /// Clean up calendar events for missed slots.
  ///
  /// Per PLAN.md: A slot is "missed" when:
  /// - now > plannedEndTime + 15 minutes
  /// - User never started working (sessionStartTime == null)
  /// - Slot is not discarded
  /// - Slot has a Google Calendar event (was synced on "Start My Day")
  ///
  /// Action: DELETE the Google Calendar event so the calendar only shows
  /// what the user accomplished, not what they missed.
  ///
  /// Returns the number of calendar events queued for deletion.
  Future<int> cleanupMissedSlots() async {
    // Only cleanup if connected to Google Calendar
    if (!GoogleCalendarService().isConnected) {
      return 0;
    }

    int cleanedCount = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check all tasks for today
    for (final task in _tasks) {
      // Only process tasks for today
      if (!_isSameDay(task.scheduledDate, today)) {
        continue;
      }

      for (int i = 0; i < task.timeSlots.length; i++) {
        final slot = task.timeSlots[i];

        // Skip slots that don't need cleanup
        if (!_shouldCleanupMissedSlot(slot, now)) {
          continue;
        }

        // Queue deletion of the calendar event
        await SyncService().queueDeleteEvent(
          taskId: task.id,
          timeSlotId: slot.id,
          googleCalendarEventId: slot.googleCalendarEventId!,
        );

        // Mark slot as discarded and clear calendar ID to prevent re-processing
        task.timeSlots[i] = slot.copyWith(
          isDiscarded: true,
          clearGoogleCalendarEventId: true,
        );

        cleanedCount++;
      }

      // Save the task if we modified any slots
      if (cleanedCount > 0) {
        await _storageService.updateSignalTask(task);
      }
    }

    // Notify listeners if we cleaned up any slots
    if (cleanedCount > 0) {
      notifyListeners();
      debugPrint('[MissedSlotCleanup] Cleaned up $cleanedCount missed slot(s)');
    }

    return cleanedCount;
  }

  /// Determines if a slot should have its calendar event cleaned up.
  ///
  /// Returns true if:
  /// 1. Slot has a calendar event (googleCalendarEventId != null)
  /// 2. Slot is past planned end + merge threshold (15 min)
  /// 3. Slot was never started (no session work)
  /// 4. Slot is not already discarded
  /// 5. Slot is not imported from external calendar (we don't own those)
  bool _shouldCleanupMissedSlot(TimeSlot slot, DateTime now) {
    // Must have a Signal-created calendar event
    if (slot.googleCalendarEventId == null) return false;

    // Must not already be discarded
    if (slot.isDiscarded) return false;

    // Must not be imported from external calendar
    if (slot.isImportedFromExternal) return false;

    // Must be past planned end + merge threshold
    final cleanupTime = slot.plannedEndTime.add(sessionMergeThreshold);
    if (now.isBefore(cleanupTime)) return false;

    // Must never have been started (no session work)
    // Check both sessionStartTime and accumulatedSeconds to be thorough
    if (slot.sessionStartTime != null || slot.accumulatedSeconds > 0) {
      return false;
    }

    return true;
  }

  // ============ Phase: "Start My Day" Calendar Sync ============

  /// Sync a single time slot to Google Calendar if eligible.
  /// Called when user schedules a slot AFTER "Start My Day" has already been completed.
  ///
  /// This creates a calendar event for the slot if it:
  /// 1. Is for today
  /// 2. Doesn't already have a Google Calendar event ID
  /// 3. Is not discarded
  /// 4. Is not imported from external calendar
  ///
  /// This mirrors the eligibility checks in [syncScheduledSlotsToCalendar] but
  /// operates on a single slot for use in mid-day scheduling flows.
  Future<bool> syncTimeSlotToCalendarIfNeeded(
    SignalTask task,
    TimeSlot slot,
  ) async {
    try {
      // Only sync if connected to Google Calendar
      if (!GoogleCalendarService().isConnected) {
        return false;
      }

      final today = DateTime.now();

      // Skip if:
      // - Slot already has a calendar event (avoid duplicates)
      // - Slot is discarded
      // - Slot is for a different day
      // - Slot is imported from external calendar (we don't own it)
      // - Slot has already been synced
      if (slot.googleCalendarEventId != null ||
          slot.isDiscarded ||
          slot.isImportedFromExternal ||
          slot.hasSyncedToCalendar ||
          !_isSameDay(slot.plannedStartTime, today)) {
        return false;
      }

      // Find the slot in the task
      final slotIndex = task.timeSlots.indexWhere((s) => s.id == slot.id);
      if (slotIndex == -1) {
        return false;
      }

      // Create updated slot and task immutably to prevent race conditions
      final updatedSlots = List<TimeSlot>.from(task.timeSlots);
      updatedSlots[slotIndex] = slot.copyWith(hasSyncedToCalendar: true);
      final updatedTask = task.copyWith(timeSlots: updatedSlots);

      // Persist to storage
      await _storageService.updateSignalTask(updatedTask);

      // Update local list if this task is for the selected date
      final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
        notifyListeners();
      }

      // Queue the calendar event creation with proper color mapping
      final tagColorHex = updatedTask.tagIds.isNotEmpty
          ? _storageService.getTag(updatedTask.tagIds.first)?.colorHex
          : null;
      await SyncService().queueCreateEvent(
        task: updatedTask,
        slot: updatedSlots[slotIndex],
        colorHex: tagColorHex,
      );

      return true;
    } catch (e) {
      debugPrint('Error syncing time slot to calendar: $e');
      return false;
    }
  }

  /// Sync all scheduled slots for today to Google Calendar.
  /// Called when user clicks "Start My Day" in the initial scheduling screen.
  ///
  /// This creates calendar events for all scheduled time slots that:
  /// 1. Are for today
  /// 2. Don't already have a Google Calendar event ID
  /// 3. Are not discarded
  ///
  /// Returns the number of slots successfully queued for sync.
  Future<int> syncScheduledSlotsToCalendar() async {
    // Only sync if connected to Google Calendar
    if (!GoogleCalendarService().isConnected) {
      return 0;
    }

    int syncedCount = 0;
    final today = DateTime.now();

    for (final task in scheduledTasks) {
      for (int i = 0; i < task.timeSlots.length; i++) {
        final slot = task.timeSlots[i];

        // Skip if:
        // - Slot already has a calendar event (avoid duplicates)
        // - Slot is discarded
        // - Slot is for a different day
        // - Slot is imported from external calendar (we don't own it)
        if (slot.googleCalendarEventId != null ||
            slot.isDiscarded ||
            slot.isImportedFromExternal ||
            !_isSameDay(slot.plannedStartTime, today)) {
          continue;
        }

        // Mark as synced BEFORE queuing to prevent duplicate creations
        // if this method is called multiple times rapidly
        task.timeSlots[i] = slot.copyWith(hasSyncedToCalendar: true);

        // Queue the calendar event creation with proper color mapping
        final tagColorHex = task.tagIds.isNotEmpty
            ? _storageService.getTag(task.tagIds.first)?.colorHex
            : null;
        await SyncService().queueCreateEvent(
          task: task,
          slot: slot,
          colorHex: tagColorHex,
        );
        syncedCount++;
      }

      // Save the task with updated hasSyncedToCalendar flags
      await _storageService.updateSignalTask(task);
    }

    // Notify listeners since we updated task state
    if (syncedCount > 0) {
      notifyListeners();
    }

    return syncedCount;
  }
}
