import 'package:uuid/uuid.dart';

import '../models/rollover_suggestion.dart';
import '../models/signal_task.dart';

/// Service for managing rollover logic for incomplete tasks
///
/// Detects incomplete tasks at end of day, generates rollover suggestions,
/// and creates new tasks when users accept suggestions.
class RolloverService {
  /// Threshold for considering a task "complete enough" (90%)
  /// Tasks with actual time >= estimated * threshold won't roll over
  static const double completionThreshold = 0.9;

  final Uuid _uuid = const Uuid();

  /// Determines if a task should be rolled over to the next day
  ///
  /// A task should roll over if:
  /// - It's not marked as complete
  /// - It's not already rolled
  /// - Its actual time is less than 90% of estimated time
  /// - It has remaining time (estimated > 0)
  bool shouldRollOver(SignalTask task) {
    // Already complete - no rollover needed
    if (task.isComplete) return false;

    // Already rolled - don't duplicate
    if (task.status == TaskStatus.rolled) return false;

    // No estimated time - nothing to roll over
    if (task.estimatedMinutes <= 0) return false;

    // Check if actual time is below threshold
    final completionRatio = task.actualMinutes / task.estimatedMinutes;
    return completionRatio < completionThreshold;
  }

  /// Calculates remaining minutes for a task
  ///
  /// Returns estimated - actual, minimum 0
  int calculateRemainingMinutes(SignalTask task) {
    final remaining = task.estimatedMinutes - task.actualMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Creates a rollover suggestion from an incomplete task
  RolloverSuggestion createSuggestionFromTask({
    required SignalTask task,
    required DateTime suggestedForDate,
  }) {
    return RolloverSuggestion(
      id: _uuid.v4(),
      originalTaskId: task.id,
      originalTaskTitle: task.title,
      suggestedMinutes: calculateRemainingMinutes(task),
      tagIds: List<String>.from(task.tagIds),
      suggestedForDate: suggestedForDate,
      createdAt: DateTime.now(),
      status: SuggestionStatus.pending,
    );
  }

  /// Detects incomplete tasks that should be rolled over
  ///
  /// Filters tasks that:
  /// - Are scheduled before the specified date
  /// - Should roll over (based on shouldRollOver logic)
  List<SignalTask> detectIncompleteTasks({
    required List<SignalTask> tasks,
    required DateTime beforeDate,
  }) {
    final normalizedBeforeDate = _normalizeDate(beforeDate);

    return tasks.where((task) {
      final normalizedScheduledDate = _normalizeDate(task.scheduledDate);

      // Task must be before the specified date
      if (!normalizedScheduledDate.isBefore(normalizedBeforeDate)) {
        return false;
      }

      // Task must meet rollover criteria
      return shouldRollOver(task);
    }).toList();
  }

  /// Generates rollover suggestions for all incomplete tasks
  List<RolloverSuggestion> generateSuggestions({
    required List<SignalTask> tasks,
    required DateTime forDate,
  }) {
    final incompleteTasks = detectIncompleteTasks(
      tasks: tasks,
      beforeDate: forDate,
    );

    return incompleteTasks.map((task) {
      return createSuggestionFromTask(task: task, suggestedForDate: forDate);
    }).toList();
  }

  /// Creates a new SignalTask from an accepted suggestion
  SignalTask createTaskFromSuggestion({
    required RolloverSuggestion suggestion,
    required DateTime scheduledDate,
  }) {
    // Use modified minutes if available, otherwise use suggested minutes
    final minutes = suggestion.finalMinutes;

    return SignalTask(
      id: _uuid.v4(),
      title: suggestion.originalTaskTitle,
      estimatedMinutes: minutes,
      tagIds: List<String>.from(suggestion.tagIds),
      status: TaskStatus.notStarted,
      scheduledDate: scheduledDate,
      isComplete: false,
      createdAt: DateTime.now(),
      rolledFromTaskId: suggestion.originalTaskId,
      remainingMinutesFromRollover: minutes,
    );
  }

  /// Filters suggestions to only pending ones for a specific date
  List<RolloverSuggestion> filterPendingSuggestionsForDate({
    required List<RolloverSuggestion> suggestions,
    required DateTime date,
  }) {
    final normalizedDate = _normalizeDate(date);

    return suggestions.where((suggestion) {
      final normalizedSuggestedDate = _normalizeDate(
        suggestion.suggestedForDate,
      );
      return suggestion.isPending &&
          _isSameDay(normalizedSuggestedDate, normalizedDate);
    }).toList();
  }

  /// Normalize date to midnight (removes time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
