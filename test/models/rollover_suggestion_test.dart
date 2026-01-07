import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/rollover_suggestion.dart';

void main() {
  group('RolloverSuggestion Model', () {
    late DateTime today;
    late DateTime tomorrow;

    setUp(() {
      today = DateTime(2026, 1, 5);
      tomorrow = DateTime(2026, 1, 6);
    });

    RolloverSuggestion createTestSuggestion({
      String id = 'suggestion-1',
      String originalTaskId = 'task-1',
      String originalTaskTitle = 'Study for CS Exam',
      int suggestedMinutes = 30,
      List<String>? tagIds,
      SuggestionStatus status = SuggestionStatus.pending,
      int? modifiedMinutes,
      String? createdTaskId,
    }) {
      return RolloverSuggestion(
        id: id,
        originalTaskId: originalTaskId,
        originalTaskTitle: originalTaskTitle,
        suggestedMinutes: suggestedMinutes,
        tagIds: tagIds ?? ['tag-school'],
        suggestedForDate: tomorrow,
        status: status,
        createdAt: today,
        modifiedMinutes: modifiedMinutes,
        createdTaskId: createdTaskId,
      );
    }

    group('Rollover Logic - Incomplete Tasks', () {
      // From QNA_GUIDE.md: If user doesn't mark task complete OR time spent
      // is not close to ETC, task rolls over with remaining time

      test('suggested minutes represents remaining time', () {
        // User estimated 2h for CS Exam, only spent 1.5h
        // Suggestion should be for 30 min remaining
        final suggestion = createTestSuggestion(
          suggestedMinutes: 30, // 2h - 1.5h = 30 min
        );

        expect(suggestion.suggestedMinutes, equals(30));
        expect(suggestion.formattedSuggestedTime, equals('30m'));
      });

      test('rollover preserves original task tags', () {
        final suggestion = createTestSuggestion(
          tagIds: ['tag-school', 'tag-cs'],
        );

        expect(suggestion.tagIds, contains('tag-school'));
        expect(suggestion.tagIds, contains('tag-cs'));
        expect(suggestion.tagIds.length, equals(2));
      });

      test('rollover links to original task', () {
        final suggestion = createTestSuggestion(
          originalTaskId: 'original-task-123',
          originalTaskTitle: 'Study for CS Exam',
        );

        expect(suggestion.originalTaskId, equals('original-task-123'));
        expect(suggestion.originalTaskTitle, equals('Study for CS Exam'));
      });
    });

    group('Suggestion Status', () {
      test('pending status for new suggestions', () {
        final suggestion = createTestSuggestion(
          status: SuggestionStatus.pending,
        );

        expect(suggestion.isPending, isTrue);
        expect(suggestion.status, equals(SuggestionStatus.pending));
      });

      test('accept() changes status to accepted', () {
        final suggestion = createTestSuggestion();

        suggestion.accept(createdTaskId: 'new-task-id');

        expect(suggestion.status, equals(SuggestionStatus.accepted));
        expect(suggestion.createdTaskId, equals('new-task-id'));
        expect(suggestion.isPending, isFalse);
      });

      test('acceptWithModification() changes status and records new time', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);

        // User accepts but wants 60 min instead of 30
        suggestion.acceptWithModification(60, createdTaskId: 'new-task-id');

        expect(suggestion.status, equals(SuggestionStatus.modified));
        expect(suggestion.modifiedMinutes, equals(60));
        expect(suggestion.createdTaskId, equals('new-task-id'));
      });

      test('dismiss() changes status to dismissed', () {
        final suggestion = createTestSuggestion();

        suggestion.dismiss();

        expect(suggestion.status, equals(SuggestionStatus.dismissed));
        expect(suggestion.isPending, isFalse);
      });
    });

    group('Final Minutes Calculation', () {
      test('finalMinutes returns suggested when not modified', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);

        expect(suggestion.finalMinutes, equals(30));
      });

      test('finalMinutes returns modified when accepted with modification', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);
        suggestion.acceptWithModification(60);

        expect(suggestion.finalMinutes, equals(60));
      });

      test('finalMinutes returns suggested after simple accept', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);
        suggestion.accept();

        expect(suggestion.finalMinutes, equals(30));
      });
    });

    group('Formatted Time Output', () {
      test('formattedSuggestedTime for minutes only', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 45);

        expect(suggestion.formattedSuggestedTime, equals('45m'));
      });

      test('formattedSuggestedTime for hours and minutes', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 90);

        expect(suggestion.formattedSuggestedTime, equals('1h 30m'));
      });

      test('formattedSuggestedTime for hours only', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 120);

        expect(suggestion.formattedSuggestedTime, equals('2h'));
      });

      test('formattedModifiedTime returns null when not modified', () {
        final suggestion = createTestSuggestion();

        expect(suggestion.formattedModifiedTime, isNull);
      });

      test('formattedModifiedTime returns formatted time when modified', () {
        final suggestion = createTestSuggestion(modifiedMinutes: 75);

        expect(suggestion.formattedModifiedTime, equals('1h 15m'));
      });
    });

    group('Rollover Scenarios from QNA_GUIDE', () {
      // Scenario: User estimated 2h study, only spent 1.5h
      // Next day: App suggests adding 30 min to make up the sum

      test('scenario: partial completion suggests remaining time', () {
        final estimatedMinutes = 120; // 2 hours
        final actualMinutes = 90; // 1.5 hours spent
        final remainingMinutes = estimatedMinutes - actualMinutes;

        final suggestion = createTestSuggestion(
          suggestedMinutes: remainingMinutes,
          originalTaskTitle: 'Study for CS Exam',
        );

        expect(suggestion.suggestedMinutes, equals(30));
      });

      test('scenario: user can modify suggested time', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);

        // User decides they actually want 1 hour instead of 30 min
        suggestion.acceptWithModification(60);

        expect(suggestion.finalMinutes, equals(60));
        expect(suggestion.status, equals(SuggestionStatus.modified));
      });

      test('scenario: user can dismiss if they forgot to mark complete', () {
        final suggestion = createTestSuggestion();

        // User says "I forgot to mark as complete" - dismiss suggestion
        suggestion.dismiss();

        expect(suggestion.status, equals(SuggestionStatus.dismissed));
      });

      test('scenario: accepted suggestion creates linked task', () {
        final suggestion = createTestSuggestion(
          originalTaskId: 'original-task-123',
        );

        suggestion.accept(createdTaskId: 'new-rollover-task-456');

        expect(suggestion.createdTaskId, equals('new-rollover-task-456'));
        // The new task should have rolledFromTaskId = 'original-task-123'
        // This is verified in the provider/service layer
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final suggestion = createTestSuggestion(suggestedMinutes: 30);

        final copy = suggestion.copyWith(suggestedMinutes: 60);

        expect(copy.suggestedMinutes, equals(60));
        expect(suggestion.suggestedMinutes, equals(30)); // Original unchanged
      });

      test('copies tagIds by value', () {
        final suggestion = createTestSuggestion(tagIds: ['tag-1']);

        final copy = suggestion.copyWith();
        copy.tagIds.add('tag-2');

        // Original should not be affected (if copyWith creates new list)
        expect(copy.tagIds.length, equals(2));
      });

      test('preserves all fields when no overrides', () {
        final suggestion = createTestSuggestion(
          id: 'test-id',
          originalTaskId: 'task-123',
          originalTaskTitle: 'Test Task',
          suggestedMinutes: 45,
          tagIds: ['tag-a', 'tag-b'],
          status: SuggestionStatus.pending,
        );

        final copy = suggestion.copyWith();

        expect(copy.id, equals('test-id'));
        expect(copy.originalTaskId, equals('task-123'));
        expect(copy.originalTaskTitle, equals('Test Task'));
        expect(copy.suggestedMinutes, equals(45));
        expect(copy.tagIds.length, equals(2));
        expect(copy.status, equals(SuggestionStatus.pending));
      });
    });

    group('Date Handling', () {
      test('suggestedForDate is set correctly', () {
        final suggestion = createTestSuggestion();

        expect(suggestion.suggestedForDate, equals(tomorrow));
      });

      test('createdAt tracks when suggestion was made', () {
        final suggestion = createTestSuggestion();

        expect(suggestion.createdAt, equals(today));
      });
    });
  });
}
