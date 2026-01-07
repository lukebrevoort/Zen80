import 'package:hive/hive.dart';

part 'task.g.dart';

/// Represents whether a task is Signal (critical) or Noise (everything else)
@HiveType(typeId: 0)
enum TaskType {
  @HiveField(0)
  signal,
  @HiveField(1)
  noise,
}

/// A task that the user needs to complete
@HiveType(typeId: 1)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  TaskType type;

  @HiveField(3)
  int timeSpentSeconds; // Store as seconds for Hive compatibility

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime date; // The day this task belongs to

  @HiveField(7)
  DateTime? timerStartedAt; // When the timer was started (null if not running)

  Task({
    required this.id,
    required this.title,
    required this.type,
    this.timeSpentSeconds = 0,
    this.isCompleted = false,
    required this.createdAt,
    required this.date,
    this.timerStartedAt,
  });

  /// Whether the timer is currently running for this task
  bool get isTimerRunning => timerStartedAt != null;

  /// Get the current elapsed time from the running timer
  Duration get currentTimerElapsed {
    if (timerStartedAt == null) return Duration.zero;
    return DateTime.now().difference(timerStartedAt!);
  }

  /// Get total time including any currently running timer
  Duration get totalTimeIncludingTimer {
    return timeSpent + currentTimerElapsed;
  }

  /// Get time spent as Duration
  Duration get timeSpent => Duration(seconds: timeSpentSeconds);

  /// Set time spent from Duration
  set timeSpent(Duration duration) {
    timeSpentSeconds = duration.inSeconds;
  }

  /// Add time to this task
  void addTime(Duration duration) {
    timeSpentSeconds += duration.inSeconds;
  }

  /// Format time spent as readable string (e.g., "1h 30m")
  String get formattedTime {
    return _formatDuration(timeSpent);
  }

  /// Format total time including running timer
  String get formattedTotalTime {
    return _formatDuration(totalTimeIncludingTimer);
  }

  /// Format a duration as readable string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Start the timer
  void startTimer() {
    timerStartedAt = DateTime.now();
  }

  /// Stop the timer and add elapsed time to total
  void stopTimer() {
    if (timerStartedAt != null) {
      timeSpentSeconds += currentTimerElapsed.inSeconds;
      timerStartedAt = null;
    }
  }

  /// Create a copy of this task with optional overrides
  Task copyWith({
    String? id,
    String? title,
    TaskType? type,
    int? timeSpentSeconds,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? date,
    DateTime? timerStartedAt,
    bool clearTimerStartedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      date: date ?? this.date,
      timerStartedAt: clearTimerStartedAt
          ? null
          : (timerStartedAt ?? this.timerStartedAt),
    );
  }
}
