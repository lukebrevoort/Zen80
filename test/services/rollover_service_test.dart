import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/signal_task.dart';
import 'package:signal_noise/models/time_slot.dart';
import 'package:signal_noise/models/rollover_suggestion.dart';
import 'package:signal_noise/services/rollover_service.dart';

void main() {
  group('RolloverService', () {
    late RolloverService rolloverService;
    late DateTime today;
    late DateTime yesterday;
    late DateTime tomorrow;

    setUp(() {
      rolloverService = RolloverService();
      today = DateTime(2026, 1, 5);
      yesterday = DateTime(2026, 1, 4);
      tomorrow = DateTime(2026, 1, 6);
    });

    // Helper to create test tasks
    SignalTask createTestTask({
      String id = 'task-1',
      String title = 'Study for CS Exam',
      int estimatedMinutes = 120,
      int actualMinutes = 0,
      List<String>? tagIds,
      TaskStatus status = TaskStatus.notStarted,
      DateTime? scheduledDate,
      bool isComplete = false,
    }) {
      final task = SignalTask(
        id: id,
        title: title,
        estimatedMinutes: estimatedMinutes,
        tagIds: tagIds ?? ['tag-school'],
        status: status,
        scheduledDate: scheduledDate ?? yesterday,
        isComplete: isComplete,
        createdAt: yesterday,
      );

      // Add time slots to simulate actual work if actualMinutes > 0
      if (actualMinutes > 0) {
        final startTime = DateTime(
          task.scheduledDate.year,
          task.scheduledDate.month,
          task.scheduledDate.day,
          9,
          0,
        );
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: startTime,
          plannedEndTime: startTime.add(Duration(minutes: estimatedMinutes)),
          actualStartTime: startTime,
          actualEndTime: startTime.add(Duration(minutes: actualMinutes)),
          accumulatedSeconds: actualMinutes * 60,
        );
        task.timeSlots.add(slot);
      }

      return task;
    }

    group('shouldRollOver - Incomplete Task Detection', () {
      // From QNA_GUIDE: "If user doesn't mark task complete OR time spent
      // is not close to ETC, task rolls over with remaining time"
      // Using 90% threshold as "close to ETC"

      test('returns true when task is not complete and has no work', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          actualMinutes: 0,
          isComplete: false,
        );

        expect(rolloverService.shouldRollOver(task), isTrue);
      });

      test('returns true when actual time is less than 90% of estimated', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          actualMinutes: 90, // 75% - below threshold
          isComplete: false,
        );

        expect(rolloverService.shouldRollOver(task), isTrue);
      });

      test('returns false when actual time is 90% or more of estimated', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          actualMinutes: 108, // Exactly 90%
          isComplete: false,
        );

        expect(rolloverService.shouldRollOver(task), isFalse);
      });

      test('returns false when task is marked complete', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          actualMinutes: 60, // Only 50%, but marked complete
          isComplete: true,
          status: TaskStatus.completed,
        );

        expect(rolloverService.shouldRollOver(task), isFalse);
      });

      test('returns false when task is already rolled', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          actualMinutes: 60,
          status: TaskStatus.rolled,
        );

        expect(rolloverService.shouldRollOver(task), isFalse);
      });

      test('returns true when estimated time is zero (edge case)', () {
        // Edge case: task with 0 estimated time should not roll over
        final task = createTestTask(
          estimatedMinutes: 0,
          actualMinutes: 0,
          isComplete: false,
        );

        // No remaining time to roll over
        expect(rolloverService.shouldRollOver(task), isFalse);
      });
    });

    group('calculateRemainingMinutes', () {
      test('returns estimated minus actual', () {
        final task = createTestTask(estimatedMinutes: 120, actualMinutes: 90);

        expect(rolloverService.calculateRemainingMinutes(task), equals(30));
      });

      test('returns 0 when actual exceeds estimated', () {
        final task = createTestTask(estimatedMinutes: 60, actualMinutes: 90);

        expect(rolloverService.calculateRemainingMinutes(task), equals(0));
      });

      test('returns full estimated when no work done', () {
        final task = createTestTask(estimatedMinutes: 120, actualMinutes: 0);

        expect(rolloverService.calculateRemainingMinutes(task), equals(120));
      });
    });

    group('createSuggestionFromTask', () {
      test('creates suggestion with correct remaining time', () {
        final task = createTestTask(
          id: 'task-123',
          title: 'Study for CS Exam',
          estimatedMinutes: 120,
          actualMinutes: 90,
          tagIds: ['tag-school', 'tag-cs'],
          scheduledDate: yesterday,
        );

        final suggestion = rolloverService.createSuggestionFromTask(
          task: task,
          suggestedForDate: today,
        );

        expect(suggestion.originalTaskId, equals('task-123'));
        expect(suggestion.originalTaskTitle, equals('Study for CS Exam'));
        expect(suggestion.suggestedMinutes, equals(30));
        expect(suggestion.tagIds, containsAll(['tag-school', 'tag-cs']));
        expect(suggestion.suggestedForDate, equals(today));
        expect(suggestion.status, equals(SuggestionStatus.pending));
      });

      test('copies all tags from original task', () {
        final task = createTestTask(
          tagIds: ['tag-personal', 'tag-work', 'tag-urgent'],
        );

        final suggestion = rolloverService.createSuggestionFromTask(
          task: task,
          suggestedForDate: today,
        );

        expect(suggestion.tagIds.length, equals(3));
        expect(
          suggestion.tagIds,
          containsAll(['tag-personal', 'tag-work', 'tag-urgent']),
        );
      });
    });

    group('detectIncompleteTasks', () {
      test('finds incomplete tasks before specified date', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            scheduledDate: yesterday,
            estimatedMinutes: 120,
            actualMinutes: 60,
            isComplete: false,
          ),
          createTestTask(
            id: 'task-2',
            scheduledDate: yesterday,
            estimatedMinutes: 60,
            actualMinutes: 60,
            isComplete: true,
            status: TaskStatus.completed,
          ),
          createTestTask(
            id: 'task-3',
            scheduledDate: today, // Today, should not be included
            estimatedMinutes: 120,
            actualMinutes: 0,
          ),
        ];

        final incomplete = rolloverService.detectIncompleteTasks(
          tasks: tasks,
          beforeDate: today,
        );

        expect(incomplete.length, equals(1));
        expect(incomplete.first.id, equals('task-1'));
      });

      test('excludes already rolled tasks', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            scheduledDate: yesterday,
            status: TaskStatus.rolled,
          ),
        ];

        final incomplete = rolloverService.detectIncompleteTasks(
          tasks: tasks,
          beforeDate: today,
        );

        expect(incomplete, isEmpty);
      });

      test('excludes completed tasks', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            scheduledDate: yesterday,
            isComplete: true,
            status: TaskStatus.completed,
          ),
        ];

        final incomplete = rolloverService.detectIncompleteTasks(
          tasks: tasks,
          beforeDate: today,
        );

        expect(incomplete, isEmpty);
      });

      test('excludes tasks at or near 90% completion', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            scheduledDate: yesterday,
            estimatedMinutes: 100,
            actualMinutes: 90, // Exactly 90%
          ),
        ];

        final incomplete = rolloverService.detectIncompleteTasks(
          tasks: tasks,
          beforeDate: today,
        );

        expect(incomplete, isEmpty);
      });
    });

    group('generateSuggestions', () {
      test('creates suggestions for all incomplete tasks', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            title: 'Task 1',
            estimatedMinutes: 120,
            actualMinutes: 60,
            scheduledDate: yesterday,
          ),
          createTestTask(
            id: 'task-2',
            title: 'Task 2',
            estimatedMinutes: 60,
            actualMinutes: 30,
            scheduledDate: yesterday,
          ),
        ];

        final suggestions = rolloverService.generateSuggestions(
          tasks: tasks,
          forDate: today,
        );

        expect(suggestions.length, equals(2));
        expect(suggestions[0].originalTaskId, equals('task-1'));
        expect(suggestions[0].suggestedMinutes, equals(60));
        expect(suggestions[1].originalTaskId, equals('task-2'));
        expect(suggestions[1].suggestedMinutes, equals(30));
      });

      test('returns empty list when no incomplete tasks', () {
        final tasks = [
          createTestTask(
            id: 'task-1',
            estimatedMinutes: 60,
            actualMinutes: 60,
            isComplete: true,
            status: TaskStatus.completed,
            scheduledDate: yesterday,
          ),
        ];

        final suggestions = rolloverService.generateSuggestions(
          tasks: tasks,
          forDate: today,
        );

        expect(suggestions, isEmpty);
      });

      test('only considers tasks before the specified date', () {
        final tasks = [
          createTestTask(
            id: 'task-yesterday',
            scheduledDate: yesterday,
            estimatedMinutes: 60,
            actualMinutes: 30,
          ),
          createTestTask(
            id: 'task-today',
            scheduledDate: today,
            estimatedMinutes: 60,
            actualMinutes: 0,
          ),
        ];

        final suggestions = rolloverService.generateSuggestions(
          tasks: tasks,
          forDate: today,
        );

        expect(suggestions.length, equals(1));
        expect(suggestions.first.originalTaskId, equals('task-yesterday'));
      });
    });

    group('createTaskFromSuggestion', () {
      test('creates new task with correct properties', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-task-123',
          originalTaskTitle: 'Study for CS Exam',
          suggestedMinutes: 30,
          tagIds: ['tag-school', 'tag-cs'],
          suggestedForDate: today,
          createdAt: yesterday,
        );

        final newTask = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );

        expect(newTask.title, equals('Study for CS Exam'));
        expect(newTask.estimatedMinutes, equals(30));
        expect(newTask.tagIds, containsAll(['tag-school', 'tag-cs']));
        expect(newTask.scheduledDate, equals(today));
        expect(newTask.rolledFromTaskId, equals('original-task-123'));
        expect(newTask.remainingMinutesFromRollover, equals(30));
        expect(newTask.status, equals(TaskStatus.notStarted));
        expect(newTask.isComplete, isFalse);
      });

      test('uses modified minutes when suggestion was modified', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-task-123',
          originalTaskTitle: 'Study for CS Exam',
          suggestedMinutes: 30,
          tagIds: ['tag-school'],
          suggestedForDate: today,
          createdAt: yesterday,
          modifiedMinutes: 60, // User modified to 60 min
          status: SuggestionStatus.modified,
        );

        final newTask = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );

        expect(newTask.estimatedMinutes, equals(60));
        expect(newTask.remainingMinutesFromRollover, equals(60));
      });

      test('generates unique ID for new task', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-task-123',
          originalTaskTitle: 'Test Task',
          suggestedMinutes: 30,
          suggestedForDate: today,
          createdAt: yesterday,
        );

        final task1 = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );
        final task2 = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );

        expect(task1.id, isNot(equals(task2.id)));
      });
    });

    group('Rollover Scenarios from QNA_GUIDE', () {
      // Scenario: User estimated 2h for CS Exam, only spent 1.5h
      // Next day: Suggests 30 min to make up the sum

      test('scenario: partial completion suggests remaining time', () {
        final task = createTestTask(
          title: 'Study for CS Exam',
          estimatedMinutes: 120, // 2 hours
          actualMinutes: 90, // 1.5 hours spent
          tagIds: ['tag-school', 'tag-cs'],
          scheduledDate: yesterday,
        );

        expect(rolloverService.shouldRollOver(task), isTrue);

        final remaining = rolloverService.calculateRemainingMinutes(task);
        expect(remaining, equals(30));

        final suggestion = rolloverService.createSuggestionFromTask(
          task: task,
          suggestedForDate: today,
        );
        expect(suggestion.suggestedMinutes, equals(30));
        expect(suggestion.formattedSuggestedTime, equals('30m'));
      });

      test('scenario: user accepts suggestion creates linked task', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-cs-task',
          originalTaskTitle: 'Study for CS Exam',
          suggestedMinutes: 30,
          tagIds: ['tag-school', 'tag-cs'],
          suggestedForDate: today,
          createdAt: yesterday,
        );

        suggestion.accept(createdTaskId: 'new-rolled-task');

        final newTask = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );

        expect(newTask.rolledFromTaskId, equals('original-cs-task'));
        expect(newTask.isRollover, isTrue);
      });

      test('scenario: user modifies suggested time', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-task',
          originalTaskTitle: 'Study for CS Exam',
          suggestedMinutes: 30,
          suggestedForDate: today,
          createdAt: yesterday,
        );

        // User decides they want 1 hour instead of 30 min
        suggestion.acceptWithModification(60, createdTaskId: 'new-task');

        final newTask = rolloverService.createTaskFromSuggestion(
          suggestion: suggestion,
          scheduledDate: today,
        );

        expect(newTask.estimatedMinutes, equals(60));
        expect(suggestion.status, equals(SuggestionStatus.modified));
      });

      test('scenario: user dismisses suggestion (forgot to mark complete)', () {
        final suggestion = RolloverSuggestion(
          id: 'suggestion-1',
          originalTaskId: 'original-task',
          originalTaskTitle: 'Study for CS Exam',
          suggestedMinutes: 30,
          suggestedForDate: today,
          createdAt: yesterday,
        );

        suggestion.dismiss();

        expect(suggestion.status, equals(SuggestionStatus.dismissed));
        expect(suggestion.isPending, isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles task with zero estimated time', () {
        final task = createTestTask(estimatedMinutes: 0, actualMinutes: 0);

        expect(rolloverService.shouldRollOver(task), isFalse);
        expect(rolloverService.calculateRemainingMinutes(task), equals(0));
      });

      test('handles task where actual exceeds estimated', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          actualMinutes: 120, // Worked twice as long
        );

        expect(rolloverService.shouldRollOver(task), isFalse);
        expect(rolloverService.calculateRemainingMinutes(task), equals(0));
      });

      test('handles task with no tags', () {
        final task = createTestTask(
          tagIds: [],
          estimatedMinutes: 60,
          actualMinutes: 30,
        );

        final suggestion = rolloverService.createSuggestionFromTask(
          task: task,
          suggestedForDate: today,
        );

        expect(suggestion.tagIds, isEmpty);
      });

      test('handles multiple days of incomplete tasks', () {
        final twoDaysAgo = yesterday.subtract(const Duration(days: 1));

        final tasks = [
          createTestTask(
            id: 'task-two-days-ago',
            scheduledDate: twoDaysAgo,
            estimatedMinutes: 60,
            actualMinutes: 30,
          ),
          createTestTask(
            id: 'task-yesterday',
            scheduledDate: yesterday,
            estimatedMinutes: 60,
            actualMinutes: 20,
          ),
        ];

        final suggestions = rolloverService.generateSuggestions(
          tasks: tasks,
          forDate: today,
        );

        // Both tasks should generate suggestions
        expect(suggestions.length, equals(2));
      });
    });

    group('Rollover Threshold (90%)', () {
      // The threshold for "close to ETC" is 90%

      test('89% completion should roll over', () {
        final task = createTestTask(estimatedMinutes: 100, actualMinutes: 89);

        expect(rolloverService.shouldRollOver(task), isTrue);
      });

      test('90% completion should NOT roll over', () {
        final task = createTestTask(estimatedMinutes: 100, actualMinutes: 90);

        expect(rolloverService.shouldRollOver(task), isFalse);
      });

      test('91% completion should NOT roll over', () {
        final task = createTestTask(estimatedMinutes: 100, actualMinutes: 91);

        expect(rolloverService.shouldRollOver(task), isFalse);
      });

      test('threshold is configurable via constant', () {
        expect(RolloverService.completionThreshold, equals(0.9));
      });
    });

    group('filterPendingSuggestionsForDate', () {
      test('returns only pending suggestions for specified date', () {
        final suggestions = [
          RolloverSuggestion(
            id: 'sug-1',
            originalTaskId: 'task-1',
            originalTaskTitle: 'Task 1',
            suggestedMinutes: 30,
            suggestedForDate: today,
            createdAt: yesterday,
            status: SuggestionStatus.pending,
          ),
          RolloverSuggestion(
            id: 'sug-2',
            originalTaskId: 'task-2',
            originalTaskTitle: 'Task 2',
            suggestedMinutes: 60,
            suggestedForDate: today,
            createdAt: yesterday,
            status: SuggestionStatus.accepted, // Not pending
          ),
          RolloverSuggestion(
            id: 'sug-3',
            originalTaskId: 'task-3',
            originalTaskTitle: 'Task 3',
            suggestedMinutes: 45,
            suggestedForDate: tomorrow, // Different date
            createdAt: today,
            status: SuggestionStatus.pending,
          ),
        ];

        final pending = rolloverService.filterPendingSuggestionsForDate(
          suggestions: suggestions,
          date: today,
        );

        expect(pending.length, equals(1));
        expect(pending.first.id, equals('sug-1'));
      });

      test('returns empty list when no pending suggestions', () {
        final suggestions = [
          RolloverSuggestion(
            id: 'sug-1',
            originalTaskId: 'task-1',
            originalTaskTitle: 'Task 1',
            suggestedMinutes: 30,
            suggestedForDate: today,
            createdAt: yesterday,
            status: SuggestionStatus.dismissed,
          ),
        ];

        final pending = rolloverService.filterPendingSuggestionsForDate(
          suggestions: suggestions,
          date: today,
        );

        expect(pending, isEmpty);
      });
    });
  });
}
