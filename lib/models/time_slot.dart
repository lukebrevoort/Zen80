import 'package:hive/hive.dart';

part 'time_slot.g.dart';

/// Status of a time slot for display purposes
/// Used to determine visual styling in calendar UI
enum TimeSlotStatus {
  /// Future slot, not yet started (prediction)
  scheduled,

  /// Timer currently running
  active,

  /// Timer stopped, has actual work time (fact)
  completed,

  /// Past planned time, never started
  missed,

  /// User discarded (didn't meet commitment threshold)
  discarded,
}

/// A scheduled time block for working on a Signal task
/// Tracks both planned and actual start/end times
///
/// Session Management:
/// - Sessions are continuous work periods
/// - Gaps < 15 minutes are merged into the same session
/// - Gaps >= 15 minutes create a new TimeSlot
/// - Calendar sync only happens after commitment threshold (5 min, or 10 min for 2+ hour tasks)
@HiveType(typeId: 12)
class TimeSlot {
  /// Gap threshold below which we treat a stop/start as the same continuous session.
  static const Duration sessionMergeThreshold = Duration(minutes: 15);
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime plannedStartTime;

  @HiveField(2)
  DateTime plannedEndTime;

  @HiveField(3)
  DateTime? actualStartTime; // When user actually started (null if not started)

  @HiveField(4)
  DateTime? actualEndTime; // When user actually ended (null if still running or not started)

  @HiveField(5)
  bool isActive; // Currently running

  @HiveField(6)
  bool autoEnd; // Should auto-end when planned time is up (user preference)

  @HiveField(7)
  List<String> linkedSubTaskIds; // Sub-tasks assigned to this time slot

  @HiveField(8)
  String? googleCalendarEventId; // Individual slot's calendar event

  @HiveField(9)
  bool wasManualContinue; // User manually continued past end time

  @HiveField(10)
  int accumulatedSeconds; // Total accumulated time from previous pause/resume cycles

  @HiveField(11)
  String? externalCalendarEventId; // Reference to imported external calendar event (NOT owned by Signal)

  // ============ New Session Tracking Fields ============

  @HiveField(12)
  DateTime? sessionStartTime; // When this continuous session began (for calendar event start)

  @HiveField(13)
  DateTime? lastStopTime; // When timer was last stopped (to calculate gaps for session merging)

  @HiveField(14)
  bool hasSyncedToCalendar; // True once we've created/updated the calendar event for this session

  @HiveField(15)
  bool isDiscarded; // True if session was discarded (didn't meet commitment threshold)

  TimeSlot({
    required this.id,
    required this.plannedStartTime,
    required this.plannedEndTime,
    this.actualStartTime,
    this.actualEndTime,
    this.isActive = false,
    this.autoEnd = true,
    List<String>? linkedSubTaskIds,
    this.googleCalendarEventId,
    this.wasManualContinue = false,
    this.accumulatedSeconds = 0,
    this.externalCalendarEventId,
    this.sessionStartTime,
    this.lastStopTime,
    this.hasSyncedToCalendar = false,
    this.isDiscarded = false,
  }) : linkedSubTaskIds = linkedSubTaskIds ?? [];

  /// Whether this time slot was imported from an external calendar event
  bool get isImportedFromExternal => externalCalendarEventId != null;

  /// Whether this time slot is synced to Google Calendar (Signal-created event)
  bool get isSyncedToCalendar => googleCalendarEventId != null;

  /// Duration that was planned for this slot
  Duration get plannedDuration => plannedEndTime.difference(plannedStartTime);

  /// Actual duration worked (includes accumulated time from pause/resume cycles)
  /// Does NOT include gap time - only actual focused work
  Duration get actualDuration {
    // Base accumulated time from previous sessions
    final accumulated = Duration(seconds: accumulatedSeconds);

    // Defensive: if marked active but missing start, treat as accumulated only.
    if (isActive && actualStartTime == null) {
      return accumulated;
    }

    // If currently active, add current session time
    if (isActive && actualStartTime != null) {
      final currentSession = DateTime.now().difference(actualStartTime!);
      return accumulated + currentSession;
    }

    // If not active, just return accumulated (includes all previous sessions)
    return accumulated;
  }

  /// Duration of the current continuous session (from sessionStartTime to now or actualEndTime)
  /// This is used for calendar event span (includes gaps that were merged)
  Duration get sessionDuration {
    if (sessionStartTime == null) return Duration.zero;

    if (isActive) {
      return DateTime.now().difference(sessionStartTime!);
    } else if (actualEndTime != null) {
      return actualEndTime!.difference(sessionStartTime!);
    }

    return Duration.zero;
  }

  /// Whether this time slot has been started
  bool get hasStarted => actualStartTime != null || accumulatedSeconds > 0;

  /// Whether this time slot has been completed
  bool get isCompleted => !isActive && accumulatedSeconds > 0;

  /// Whether we're currently past the planned end time
  bool get isPastPlannedEnd => DateTime.now().isAfter(plannedEndTime);

  /// Time remaining until planned end (can be negative if past)
  Duration get timeUntilPlannedEnd => plannedEndTime.difference(DateTime.now());

  /// How much time is left in the planned slot from now
  Duration get remainingPlannedTime {
    if (DateTime.now().isAfter(plannedEndTime)) return Duration.zero;
    return plannedEndTime.difference(DateTime.now());
  }

  // ============ Phase 6.B: Predicted vs. Actual Time Support ============

  /// Whether this slot is in the future (not yet reached planned start time)
  bool get isFuture => DateTime.now().isBefore(plannedStartTime);

  /// Whether this slot is in the past (planned end time has passed and not active)
  bool get isPast => DateTime.now().isAfter(plannedEndTime) && !isActive;

  /// Whether this slot is currently within its planned time window
  bool get isWithinPlannedWindow {
    final now = DateTime.now();
    return now.isAfter(plannedStartTime) && now.isBefore(plannedEndTime);
  }

  /// The start time to show in calendar.
  /// - For finalized sessions: use actual start time (the session is locked in)
  /// - For active/resumable sessions: use session start time if available
  /// - For future/unstarted slots: use planned start time
  DateTime get calendarStartTime {
    // Finalized sessions (completed + past merge window) use actual times
    if (isSessionFinalized && sessionStartTime != null) {
      return sessionStartTime!;
    }
    // Active or resumable sessions use session start if available
    if (sessionStartTime != null && (isActive || canMergeSession)) {
      return sessionStartTime!;
    }
    // Otherwise use planned time
    return plannedStartTime;
  }

  /// The end time to show in calendar.
  /// - For finalized sessions: use actual end time (the session is locked in)
  /// - For active sessions within planned time: use planned end time (show full block)
  /// - For active sessions past planned time: use current time (show overtime)
  /// - For resumable sessions: use planned end time (might still resume)
  /// - For future/unstarted slots: use planned end time
  DateTime get calendarEndTime {
    // Finalized sessions (completed + past merge window) use actual times
    if (isSessionFinalized && actualEndTime != null) {
      return actualEndTime!;
    }
    // Active sessions: show planned end, or current time if running overtime
    if (isActive) {
      final now = DateTime.now();
      // If past planned end time, show current time (overtime indicator)
      // Otherwise show planned end time (full block visibility)
      return now.isAfter(plannedEndTime) ? now : plannedEndTime;
    }
    // Otherwise use planned time (including resumable sessions)
    return plannedEndTime;
  }

  /// Whether actual times differ significantly from planned (> 5 min)
  bool get actualDiffersFromPlanned {
    if (actualStartTime == null) return false;

    final startDiff = actualStartTime!.difference(plannedStartTime).abs();
    final endDiff = actualEndTime != null
        ? actualEndTime!.difference(plannedEndTime).abs()
        : Duration.zero;

    return startDiff > const Duration(minutes: 5) ||
        endDiff > const Duration(minutes: 5);
  }

  /// How late/early the start was compared to planned (positive = late)
  Duration get startVariance {
    if (actualStartTime == null) return Duration.zero;
    return actualStartTime!.difference(plannedStartTime);
  }

  /// How much over/under the duration was compared to planned (positive = over)
  Duration get durationVariance {
    if (actualEndTime == null) return Duration.zero;
    return actualDuration - plannedDuration;
  }

  /// Display status for UI styling
  TimeSlotStatus get displayStatus {
    if (isDiscarded) return TimeSlotStatus.discarded;
    if (isActive) return TimeSlotStatus.active;
    if (isCompleted) return TimeSlotStatus.completed;
    if (isPast && !hasStarted) return TimeSlotStatus.missed;
    return TimeSlotStatus.scheduled;
  }

  /// Formatted start variance for display (e.g., "+15m late" or "-5m early")
  String get formattedStartVariance {
    if (actualStartTime == null) return '';

    final variance = startVariance;
    final minutes = variance.inMinutes.abs();

    if (minutes < 2) return 'on time';

    if (variance.isNegative) {
      return '${minutes}m early';
    } else {
      return '+${minutes}m late';
    }
  }

  /// Formatted duration variance for display (e.g., "+30m over" or "-10m under")
  String get formattedDurationVariance {
    if (actualEndTime == null) return '';

    final variance = durationVariance;
    final minutes = variance.inMinutes.abs();

    if (minutes < 2) return 'as planned';

    if (variance.isNegative) {
      return '${minutes}m under';
    } else {
      return '+${minutes}m over';
    }
  }

  /// Check if resuming now would be within the session merge threshold (< 15 min gap)
  bool get canMergeSession {
    if (lastStopTime == null) return false;
    final gap = DateTime.now().difference(lastStopTime!);
    return gap < sessionMergeThreshold;
  }

  /// Gap duration since last stop (null if never stopped)
  Duration? get gapSinceLastStop {
    if (lastStopTime == null) return null;
    return DateTime.now().difference(lastStopTime!);
  }

  /// Whether this session is "finalized" - completed and past the merge window.
  /// A finalized session should display its actual times, not planned times,
  /// because the user can no longer resume within the same session.
  ///
  /// Per PLAN.md, a session is finalized when BOTH conditions are true:
  /// 1. now > plannedEndTime + 15 minutes (past the planned window)
  /// 2. now > lastStopTime + 15 minutes (merge window expired)
  ///
  /// Why both?
  /// - Condition 1 alone would finalize while user is still working overtime
  /// - Condition 2 alone would finalize a session that ended early, even if
  ///   there's still planned time remaining
  bool get isSessionFinalized {
    if (!isCompleted) return false;
    if (lastStopTime == null) return false;

    final now = DateTime.now();

    // Condition 1: Past planned end time + merge threshold
    final pastPlannedEnd = now.isAfter(
      plannedEndTime.add(sessionMergeThreshold),
    );

    // Condition 2: Past merge window (can't resume into same session)
    final pastMergeWindow = !canMergeSession;

    // BOTH conditions must be true for session to be finalized
    return pastPlannedEnd && pastMergeWindow;
  }

  /// Start the timer for this slot (handles both initial start and resume)
  void start() {
    final now = DateTime.now();
    actualStartTime = now;
    actualEndTime = null; // Clear end time since we're starting again
    isActive = true;
    isDiscarded = false;

    // Set session start time if this is a new session
    sessionStartTime ??= now;
  }

  /// End the timer for this slot (accumulates session time)
  void end() {
    final now = DateTime.now();

    if (actualStartTime != null && isActive) {
      // Add current session duration to accumulated time
      final sessionDuration = now.difference(actualStartTime!);
      accumulatedSeconds += sessionDuration.inSeconds;
    }

    actualEndTime = now;
    lastStopTime = now; // Record when we stopped for gap calculation
    isActive = false;
  }

  /// Discard this session (didn't meet commitment threshold)
  void discard() {
    isDiscarded = true;
    accumulatedSeconds = 0;
    actualStartTime = null;
    actualEndTime = null;
    sessionStartTime = null;
    lastStopTime = null;
    isActive = false;
  }

  /// Continue past the planned end time (user chose to keep working)
  void continueTimer() {
    wasManualContinue = true;
    autoEnd = false; // Disable auto-end since user wants to continue
  }

  /// Link a sub-task to this time slot
  void linkSubTask(String subTaskId) {
    if (!linkedSubTaskIds.contains(subTaskId)) {
      linkedSubTaskIds.add(subTaskId);
    }
  }

  /// Unlink a sub-task from this time slot
  void unlinkSubTask(String subTaskId) {
    linkedSubTaskIds.remove(subTaskId);
  }

  /// Create a copy with optional overrides
  TimeSlot copyWith({
    String? id,
    DateTime? plannedStartTime,
    DateTime? plannedEndTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    bool? isActive,
    bool? autoEnd,
    List<String>? linkedSubTaskIds,
    String? googleCalendarEventId,
    bool? wasManualContinue,
    int? accumulatedSeconds,
    String? externalCalendarEventId,
    DateTime? sessionStartTime,
    DateTime? lastStopTime,
    bool? hasSyncedToCalendar,
    bool? isDiscarded,
    bool clearActualStartTime = false,
    bool clearActualEndTime = false,
    bool clearGoogleCalendarEventId = false,
    bool clearExternalCalendarEventId = false,
    bool clearSessionStartTime = false,
    bool clearLastStopTime = false,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      actualStartTime: clearActualStartTime
          ? null
          : (actualStartTime ?? this.actualStartTime),
      actualEndTime: clearActualEndTime
          ? null
          : (actualEndTime ?? this.actualEndTime),
      isActive: isActive ?? this.isActive,
      autoEnd: autoEnd ?? this.autoEnd,
      linkedSubTaskIds: linkedSubTaskIds ?? List.from(this.linkedSubTaskIds),
      googleCalendarEventId: clearGoogleCalendarEventId
          ? null
          : (googleCalendarEventId ?? this.googleCalendarEventId),
      wasManualContinue: wasManualContinue ?? this.wasManualContinue,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      externalCalendarEventId: clearExternalCalendarEventId
          ? null
          : (externalCalendarEventId ?? this.externalCalendarEventId),
      sessionStartTime: clearSessionStartTime
          ? null
          : (sessionStartTime ?? this.sessionStartTime),
      lastStopTime: clearLastStopTime
          ? null
          : (lastStopTime ?? this.lastStopTime),
      hasSyncedToCalendar: hasSyncedToCalendar ?? this.hasSyncedToCalendar,
      isDiscarded: isDiscarded ?? this.isDiscarded,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
