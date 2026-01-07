import 'package:hive/hive.dart';
import 'sub_task.dart';
import 'time_slot.dart';

part 'signal_task.g.dart';

/// Status of a Signal task
@HiveType(typeId: 14)
enum TaskStatus {
  @HiveField(0)
  notStarted,
  @HiveField(1)
  inProgress,
  @HiveField(2)
  completed,
  @HiveField(3)
  rolled, // Rolled over to next day
}

/// A Signal task - the core unit of focused work
/// Replaces the old Task model with enhanced features
@HiveType(typeId: 15)
class SignalTask extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int estimatedMinutes; // User's estimated time to complete

  @HiveField(3)
  List<String> tagIds; // References to Tag objects

  @HiveField(4)
  List<SubTask> subTasks; // Embedded sub-tasks

  @HiveField(5)
  TaskStatus status;

  @HiveField(6)
  DateTime scheduledDate; // The day this task is planned for

  @HiveField(7)
  List<TimeSlot> timeSlots; // Scheduled time blocks

  @HiveField(8)
  String? googleCalendarEventId; // For sync (null if not synced)

  @HiveField(9)
  bool isComplete;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  String? rolledFromTaskId; // If this was rolled over from another task

  @HiveField(12)
  int remainingMinutesFromRollover; // How much time was suggested from rollover

  SignalTask({
    required this.id,
    required this.title,
    required this.estimatedMinutes,
    List<String>? tagIds,
    List<SubTask>? subTasks,
    this.status = TaskStatus.notStarted,
    required this.scheduledDate,
    List<TimeSlot>? timeSlots,
    this.googleCalendarEventId,
    this.isComplete = false,
    required this.createdAt,
    this.rolledFromTaskId,
    this.remainingMinutesFromRollover = 0,
  }) : tagIds = tagIds ?? [],
       subTasks = subTasks ?? [],
       timeSlots = timeSlots ?? [];

  /// Total actual minutes worked across all time slots
  int get actualMinutes {
    return timeSlots.fold<int>(
      0,
      (sum, slot) => sum + slot.actualDuration.inMinutes,
    );
  }

  /// Total planned minutes across all time slots
  int get plannedMinutes {
    return timeSlots.fold<int>(
      0,
      (sum, slot) => sum + slot.plannedDuration.inMinutes,
    );
  }

  /// Whether any time slot is currently active
  bool get hasActiveTimeSlot => timeSlots.any((slot) => slot.isActive);

  /// Get the currently active time slot (if any)
  TimeSlot? get activeTimeSlot {
    try {
      return timeSlots.firstWhere((slot) => slot.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Whether this task has been scheduled (has time slots)
  bool get isScheduled => timeSlots.isNotEmpty;

  // ============ Phase 6: Time Slot Splitting Support ============

  /// Total scheduled minutes across all non-discarded time slots.
  ///
  /// IMPORTANT: Once a slot has been *completed* (i.e. has actual work time), it
  /// should continue to count toward "scheduled" so the task doesn't regress
  /// to "unscheduled" after the user works on it.
  ///
  /// Using `plannedDuration` for completed slots also avoids a subtle UI bug:
  /// after stopTimeSlot, we may overwrite plannedStart/End to match the actual
  /// session for calendar sync, which would otherwise reduce scheduledMinutes to
  /// the *actual* duration and make long tasks appear partially/unscheduled.
  int get scheduledMinutes {
    return timeSlots
        .where((slot) => !slot.isDiscarded)
        .fold<int>(0, (sum, slot) => sum + slot.plannedDuration.inMinutes);
  }

  /// Remaining unscheduled minutes (estimated - scheduled)
  int get unscheduledMinutes {
    final remaining = estimatedMinutes - scheduledMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether all estimated time has been scheduled
  bool get isFullyScheduled => unscheduledMinutes == 0 && timeSlots.isNotEmpty;

  /// Whether some (but not all) time has been scheduled
  bool get isPartiallyScheduled =>
      timeSlots.isNotEmpty && unscheduledMinutes > 0;

  // ============ Phase 6B Fix: Calendar Presence vs Needs Scheduling ============

  /// Whether this task has any presence on the calendar (scheduled or worked on).
  /// A task has calendar presence if it has ANY non-discarded time slots,
  /// regardless of whether it's "fully scheduled" by duration.
  bool get hasCalendarPresence {
    return timeSlots.any((slot) => !slot.isDiscarded);
  }

  /// Whether this task needs the user to schedule more time.
  /// A task does NOT need scheduling if:
  /// 1. It has completed work (user already engaged with it), OR
  /// 2. It's fully scheduled (estimated time covered by planned slots)
  ///
  /// This prevents completed sessions from appearing in "Needs Scheduling"
  /// after the user stops the timer.
  bool get needsScheduling {
    if (timeSlots.isEmpty) return true;

    // If user has done ANY completed work, don't nag them to schedule
    final hasCompletedWork = timeSlots.any((slot) => slot.isCompleted);
    if (hasCompletedWork) return false;

    // Otherwise, check if there's still unscheduled time
    return unscheduledMinutes > 0;
  }

  /// Percentage of estimated time that has been scheduled (0.0 to 1.0)
  double get scheduledPercentage {
    if (estimatedMinutes <= 0) return 0;
    return (scheduledMinutes / estimatedMinutes).clamp(0.0, 1.0);
  }

  /// Format scheduled time as readable string
  String get formattedScheduledTime {
    return _formatMinutes(scheduledMinutes);
  }

  /// Format unscheduled time as readable string
  String get formattedUnscheduledTime {
    return _formatMinutes(unscheduledMinutes);
  }

  /// Get the earliest scheduled time slot
  TimeSlot? get earliestTimeSlot {
    if (timeSlots.isEmpty) return null;
    return timeSlots.reduce(
      (a, b) => a.plannedStartTime.isBefore(b.plannedStartTime) ? a : b,
    );
  }

  /// Progress percentage (actual vs estimated)
  double get progressPercentage {
    if (estimatedMinutes <= 0) return 0;
    return (actualMinutes / estimatedMinutes).clamp(0.0, 1.0);
  }

  /// Remaining minutes to reach estimated time
  int get remainingMinutes {
    final remaining = estimatedMinutes - actualMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Number of completed sub-tasks
  int get completedSubTaskCount => subTasks.where((st) => st.isChecked).length;

  /// Sub-task completion percentage
  double get subTaskProgressPercentage {
    if (subTasks.isEmpty) return 1.0; // No sub-tasks = 100%
    return completedSubTaskCount / subTasks.length;
  }

  /// Whether this task is a rollover from a previous day
  bool get isRollover => rolledFromTaskId != null;

  /// Format estimated time as readable string
  String get formattedEstimatedTime {
    return _formatMinutes(estimatedMinutes);
  }

  /// Format actual time as readable string
  String get formattedActualTime {
    return _formatMinutes(actualMinutes);
  }

  /// Format remaining time as readable string
  String get formattedRemainingTime {
    return _formatMinutes(remainingMinutes);
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  /// Add a new time slot
  void addTimeSlot(TimeSlot slot) {
    timeSlots.add(slot);
  }

  /// Remove a time slot by ID
  void removeTimeSlot(String slotId) {
    timeSlots.removeWhere((slot) => slot.id == slotId);
  }

  /// Add a new sub-task
  void addSubTask(SubTask subTask) {
    subTasks.add(subTask);
  }

  /// Remove a sub-task by ID
  void removeSubTask(String subTaskId) {
    subTasks.removeWhere((st) => st.id == subTaskId);
    // Also unlink from any time slots
    for (final slot in timeSlots) {
      slot.unlinkSubTask(subTaskId);
    }
  }

  /// Toggle a sub-task's checked state
  void toggleSubTask(String subTaskId) {
    final subTask = subTasks.firstWhere((st) => st.id == subTaskId);
    subTask.toggle();
  }

  /// Add a tag by ID
  void addTag(String tagId) {
    if (!tagIds.contains(tagId)) {
      tagIds.add(tagId);
    }
  }

  /// Remove a tag by ID
  void removeTag(String tagId) {
    tagIds.remove(tagId);
  }

  /// Mark the task as complete
  void markComplete() {
    isComplete = true;
    status = TaskStatus.completed;
  }

  /// Mark the task as rolled over
  void markRolled() {
    status = TaskStatus.rolled;
  }

  /// Start a specific time slot (handles both initial start and resume within session)
  /// For session merging (gap < 15 min), keeps the original sessionStartTime
  /// For new sessions (gap >= 15 min), a new slot should be created instead
  void startTimeSlot(String slotId) {
    final slotIndex = timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = timeSlots[slotIndex];
    final now = DateTime.now();

    // Determine if we're starting fresh or resuming within a session
    final bool isFirstStart = slot.sessionStartTime == null;
    final bool isResumingWithinSession = !isFirstStart && slot.canMergeSession;

    if (isFirstStart) {
      // First time starting this slot - set session start time
      timeSlots[slotIndex] = slot.copyWith(
        actualStartTime: now,
        sessionStartTime: now,
        clearActualEndTime: true,
        isActive: true,
        isDiscarded: false, // Clear discarded flag if restarting
      );
    } else if (isResumingWithinSession) {
      // Resuming within 15 min - keep original sessionStartTime
      // The gap time is NOT counted in accumulatedSeconds (only actual work time)
      timeSlots[slotIndex] = slot.copyWith(
        actualStartTime: now,
        clearActualEndTime: true,
        isActive: true,
        // sessionStartTime stays the same - for calendar event spanning
      );
    } else {
      // Gap >= 15 min - provider should create a NEW slot instead.
      // We do not mutate accumulatedSeconds here, to avoid corrupting work history.
      throw StateError(
        'Cannot resume slot after session merge threshold; create a new slot instead.',
      );
    }

    status = TaskStatus.inProgress;
    save();
  }

  /// End a specific time slot (accumulates session time)
  /// Only counts actual work time (gaps are NOT included in accumulatedSeconds)
  void endTimeSlot(String slotId) {
    final slotIndex = timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    final slot = timeSlots[slotIndex];
    final now = DateTime.now();

    // Calculate accumulated time including this session
    // Only count the actual work time from actualStartTime to now
    int newAccumulatedSeconds = slot.accumulatedSeconds;
    if (slot.actualStartTime != null && slot.isActive) {
      final workDuration = now.difference(slot.actualStartTime!);
      newAccumulatedSeconds += workDuration.inSeconds;
    }

    // Create a new slot with updated values to ensure Hive saves properly
    timeSlots[slotIndex] = slot.copyWith(
      actualEndTime: now,
      lastStopTime: now, // Record when we stopped for gap calculation
      isActive: false,
      accumulatedSeconds: newAccumulatedSeconds,
    );

    // Update status based on completion
    if (isComplete) {
      status = TaskStatus.completed;
    } else if (actualMinutes > 0) {
      // Keep in progress if there's more time slots or not complete
      status = TaskStatus.inProgress;
    }

    save();
  }

  /// Get the commitment threshold for this task
  /// 5 minutes for tasks < 2 hours, 10 minutes for tasks >= 2 hours
  Duration get commitmentThreshold {
    return estimatedMinutes >= 120
        ? const Duration(minutes: 10)
        : const Duration(minutes: 5);
  }

  /// Check if a slot has met the commitment threshold for calendar sync
  bool slotMeetsCommitmentThreshold(String slotId) {
    final slot = timeSlots.firstWhere(
      (s) => s.id == slotId,
      orElse: () => throw Exception('Slot not found'),
    );
    return slot.actualDuration >= commitmentThreshold;
  }

  /// Get the most recently stopped slot (for resumption logic)
  TimeSlot? get lastStoppedSlot {
    final stoppedSlots = timeSlots
        .where((s) => !s.isActive && s.lastStopTime != null && !s.isDiscarded)
        .toList();

    if (stoppedSlots.isEmpty) return null;

    stoppedSlots.sort((a, b) => b.lastStopTime!.compareTo(a.lastStopTime!));
    return stoppedSlots.first;
  }

  /// Check if resuming now should create a new slot (gap >= 15 min)
  bool get shouldCreateNewSlotOnResume {
    final lastSlot = lastStoppedSlot;
    if (lastSlot == null) return true; // No previous slot, create new
    return !lastSlot.canMergeSession; // Can't merge = need new slot
  }

  /// Create a copy with optional overrides
  SignalTask copyWith({
    String? id,
    String? title,
    int? estimatedMinutes,
    List<String>? tagIds,
    List<SubTask>? subTasks,
    TaskStatus? status,
    DateTime? scheduledDate,
    List<TimeSlot>? timeSlots,
    String? googleCalendarEventId,
    bool? isComplete,
    DateTime? createdAt,
    String? rolledFromTaskId,
    int? remainingMinutesFromRollover,
    bool clearGoogleCalendarEventId = false,
    bool clearRolledFromTaskId = false,
  }) {
    return SignalTask(
      id: id ?? this.id,
      title: title ?? this.title,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      tagIds: tagIds ?? List.from(this.tagIds),
      subTasks: subTasks ?? this.subTasks.map((st) => st.copyWith()).toList(),
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      timeSlots:
          timeSlots ?? this.timeSlots.map((ts) => ts.copyWith()).toList(),
      googleCalendarEventId: clearGoogleCalendarEventId
          ? null
          : (googleCalendarEventId ?? this.googleCalendarEventId),
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
      rolledFromTaskId: clearRolledFromTaskId
          ? null
          : (rolledFromTaskId ?? this.rolledFromTaskId),
      remainingMinutesFromRollover:
          remainingMinutesFromRollover ?? this.remainingMinutesFromRollover,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
