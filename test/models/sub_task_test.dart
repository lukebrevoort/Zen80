import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/sub_task.dart';

void main() {
  group('SubTask Model', () {
    group('Basic Properties', () {
      test('creates with default values', () {
        final subTask = SubTask(id: 'st-1', title: 'Review Chapter 5');

        expect(subTask.id, equals('st-1'));
        expect(subTask.title, equals('Review Chapter 5'));
        expect(subTask.isChecked, isFalse);
        expect(subTask.linkedTimeSlotIds, isEmpty);
      });

      test('creates with explicit values', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Review Chapter 5',
          isChecked: true,
          linkedTimeSlotIds: ['slot-1', 'slot-2'],
        );

        expect(subTask.isChecked, isTrue);
        expect(subTask.linkedTimeSlotIds.length, equals(2));
      });
    });

    group('Toggle Functionality', () {
      test('toggle changes false to true', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          isChecked: false,
        );

        subTask.toggle();

        expect(subTask.isChecked, isTrue);
      });

      test('toggle changes true to false', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          isChecked: true,
        );

        subTask.toggle();

        expect(subTask.isChecked, isFalse);
      });

      test('multiple toggles work correctly', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          isChecked: false,
        );

        subTask.toggle(); // false -> true
        subTask.toggle(); // true -> false
        subTask.toggle(); // false -> true

        expect(subTask.isChecked, isTrue);
      });
    });

    group('Time Slot Linking', () {
      test('linkToTimeSlot adds slot id', () {
        final subTask = SubTask(id: 'st-1', title: 'Test Task');

        subTask.linkToTimeSlot('slot-1');

        expect(subTask.linkedTimeSlotIds, contains('slot-1'));
      });

      test('linkToTimeSlot does not add duplicates', () {
        final subTask = SubTask(id: 'st-1', title: 'Test Task');

        subTask.linkToTimeSlot('slot-1');
        subTask.linkToTimeSlot('slot-1');

        expect(subTask.linkedTimeSlotIds.length, equals(1));
      });

      test('unlinkFromTimeSlot removes slot id', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          linkedTimeSlotIds: ['slot-1', 'slot-2'],
        );

        subTask.unlinkFromTimeSlot('slot-1');

        expect(subTask.linkedTimeSlotIds, isNot(contains('slot-1')));
        expect(subTask.linkedTimeSlotIds, contains('slot-2'));
      });

      test('unlinkFromTimeSlot does nothing for non-existent slot', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          linkedTimeSlotIds: ['slot-1'],
        );

        subTask.unlinkFromTimeSlot('slot-nonexistent');

        expect(subTask.linkedTimeSlotIds.length, equals(1));
      });

      test('isLinkedToTimeSlot returns true for linked slots', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          linkedTimeSlotIds: ['slot-1', 'slot-2'],
        );

        expect(subTask.isLinkedToTimeSlot('slot-1'), isTrue);
        expect(subTask.isLinkedToTimeSlot('slot-2'), isTrue);
      });

      test('isLinkedToTimeSlot returns false for unlinked slots', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test Task',
          linkedTimeSlotIds: ['slot-1'],
        );

        expect(subTask.isLinkedToTimeSlot('slot-99'), isFalse);
      });
    });

    group('SubTask Linking Scenarios', () {
      // From IMPLEMENTATION_PLAN.md: Sub-tasks can be assigned to time slots
      // So if I have a big task like FINISH WEBSITE (5h), I can create subtasks
      // and attach them to certain time blocks

      test('subtask can be linked to multiple time slots', () {
        // User might work on same subtask across multiple time blocks
        final subTask = SubTask(id: 'st-1', title: 'Fix hero section');

        subTask.linkToTimeSlot('morning-slot');
        subTask.linkToTimeSlot('afternoon-slot');

        expect(subTask.linkedTimeSlotIds.length, equals(2));
        expect(subTask.isLinkedToTimeSlot('morning-slot'), isTrue);
        expect(subTask.isLinkedToTimeSlot('afternoon-slot'), isTrue);
      });

      test('subtask with no time slot links is valid', () {
        // Subtasks are optional organizational tools
        final subTask = SubTask(id: 'st-1', title: 'Research phase');

        expect(subTask.linkedTimeSlotIds.isEmpty, isTrue);
        // SubTask should still function normally
        subTask.toggle();
        expect(subTask.isChecked, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with updated title', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Original',
          isChecked: false,
        );

        final copy = subTask.copyWith(title: 'Updated');

        expect(copy.title, equals('Updated'));
        expect(copy.id, equals('st-1'));
        expect(subTask.title, equals('Original')); // Original unchanged
      });

      test('creates copy with updated isChecked', () {
        final subTask = SubTask(id: 'st-1', title: 'Test', isChecked: false);

        final copy = subTask.copyWith(isChecked: true);

        expect(copy.isChecked, isTrue);
        expect(subTask.isChecked, isFalse);
      });

      test('copies linkedTimeSlotIds by value', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Test',
          linkedTimeSlotIds: ['slot-1'],
        );

        final copy = subTask.copyWith();
        copy.linkToTimeSlot('slot-2');

        // Original should not be affected
        expect(subTask.linkedTimeSlotIds.length, equals(1));
        expect(copy.linkedTimeSlotIds.length, equals(2));
      });

      test('preserves all fields when no overrides', () {
        final subTask = SubTask(
          id: 'st-1',
          title: 'Complete Task',
          isChecked: true,
          linkedTimeSlotIds: ['slot-1', 'slot-2'],
        );

        final copy = subTask.copyWith();

        expect(copy.id, equals('st-1'));
        expect(copy.title, equals('Complete Task'));
        expect(copy.isChecked, isTrue);
        expect(copy.linkedTimeSlotIds.length, equals(2));
      });
    });

    group('Equality', () {
      test('subtasks with same id are equal', () {
        final subTask1 = SubTask(id: 'st-1', title: 'Task A', isChecked: false);

        final subTask2 = SubTask(
          id: 'st-1',
          title: 'Task B', // Different title
          isChecked: true, // Different state
        );

        expect(subTask1, equals(subTask2));
      });

      test('subtasks with different ids are not equal', () {
        final subTask1 = SubTask(id: 'st-1', title: 'Same Title');

        final subTask2 = SubTask(id: 'st-2', title: 'Same Title');

        expect(subTask1, isNot(equals(subTask2)));
      });

      test('hashCode is based on id', () {
        final subTask1 = SubTask(id: 'st-1', title: 'Task A');

        final subTask2 = SubTask(id: 'st-1', title: 'Task B');

        expect(subTask1.hashCode, equals(subTask2.hashCode));
      });
    });
  });
}
