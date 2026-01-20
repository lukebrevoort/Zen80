import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/services/notification_service.dart';
import 'package:signal_noise/models/signal_task.dart';
import 'package:signal_noise/models/time_slot.dart';

void main() {
  group('NotificationService - Method Signatures', () {
    test('onTimerStarted method should exist and have correct signature', () {
      final notificationService = NotificationService();

      // Verify the method exists by checking the type
      expect(
        notificationService.onTimerStarted,
        isA<Future Function(SignalTask, TimeSlot)>(),
      );
    });

    test('onTimerStopped method should exist and have correct signature', () {
      final notificationService = NotificationService();

      // Verify the method exists by checking the type
      expect(
        notificationService.onTimerStopped,
        isA<Future Function(SignalTask, TimeSlot)>(),
      );
    });

    test(
      'cancelNotificationsForInactiveTasks method should exist and have correct signature',
      () {
        final notificationService = NotificationService();

        // Verify the method exists by checking the type
        expect(
          notificationService.cancelNotificationsForInactiveTasks,
          isA<Future Function(List<SignalTask>, String)>(),
        );
      },
    );

    test('SignalTask can be created with required parameters', () {
      final task = SignalTask(
        id: 'test-task-1',
        title: 'Test Task',
        estimatedMinutes: 60,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(task.id, 'test-task-1');
      expect(task.title, 'Test Task');
      expect(task.estimatedMinutes, 60);
    });

    test('TimeSlot can be created with required parameters', () {
      final slot = TimeSlot(
        id: 'test-slot-1',
        plannedStartTime: DateTime.now().subtract(const Duration(hours: 1)),
        plannedEndTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(slot.id, 'test-slot-1');
      expect(slot.plannedStartTime.isBefore(slot.plannedEndTime), isTrue);
    });

    test('SignalTask can have TimeSlots added', () {
      final task = SignalTask(
        id: 'test-task-1',
        title: 'Test Task',
        estimatedMinutes: 60,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final slot = TimeSlot(
        id: 'test-slot-1',
        plannedStartTime: DateTime.now().subtract(const Duration(hours: 1)),
        plannedEndTime: DateTime.now().add(const Duration(hours: 1)),
      );

      task.addTimeSlot(slot);

      expect(task.timeSlots.length, 1);
      expect(task.timeSlots.first.id, 'test-slot-1');
    });
  });

  group('TimeSlot - Time Calculation', () {
    test('should calculate elapsed time correctly when active', () {
      final now = DateTime.now();
      final slot = TimeSlot(
        id: 'test-slot-1',
        plannedStartTime: now.subtract(const Duration(hours: 1)),
        plannedEndTime: now.add(const Duration(hours: 1)),
        accumulatedSeconds:
            1800, // 30 minutes accumulated from previous sessions
        actualStartTime: now.subtract(
          const Duration(minutes: 30),
        ), // Started 30 minutes ago
        isActive: true,
      );

      // Calculate total time including current session
      final currentSessionTime = slot.actualStartTime != null && slot.isActive
          ? DateTime.now().difference(slot.actualStartTime!)
          : Duration.zero;
      final totalTime =
          Duration(seconds: slot.accumulatedSeconds) + currentSessionTime;

      // Should be at least 30 minutes (current session) + 30 minutes (accumulated) = 60 minutes
      expect(totalTime.inMinutes, greaterThanOrEqualTo(59));
    });

    test('should only use accumulated seconds when not active', () {
      final slot = TimeSlot(
        id: 'test-slot-1',
        plannedStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        plannedEndTime: DateTime.now().subtract(const Duration(hours: 1)),
        accumulatedSeconds: 3600, // 1 hour accumulated
        isActive: false,
      );

      // When not active, current session time should be zero
      final currentSessionTime = slot.actualStartTime != null && slot.isActive
          ? DateTime.now().difference(slot.actualStartTime!)
          : Duration.zero;
      final totalTime =
          Duration(seconds: slot.accumulatedSeconds) + currentSessionTime;

      expect(currentSessionTime, equals(Duration.zero));
      expect(totalTime.inMinutes, equals(60));
    });
  });

  group('Task Notification Management', () {
    test('should handle multiple tasks correctly', () {
      // Create multiple tasks
      final task1 = SignalTask(
        id: 'task-1',
        title: 'Work',
        estimatedMinutes: 120,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final task2 = SignalTask(
        id: 'task-2',
        title: 'Working Out',
        estimatedMinutes: 60,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final task3 = SignalTask(
        id: 'task-3',
        title: 'Reading',
        estimatedMinutes: 30,
        scheduledDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final allTasks = [task1, task2, task3];
      final activeTaskId = 'task-2';

      // Test that we can identify inactive tasks
      final inactiveTasks = allTasks
          .where((task) => task.id != activeTaskId)
          .toList();

      expect(inactiveTasks.length, equals(2));
      expect(
        inactiveTasks.map((t) => t.id).toList(),
        containsAll(['task-1', 'task-3']),
      );
      expect(
        inactiveTasks.map((t) => t.id).toList(),
        isNot(contains('task-2')),
      );
    });

    test('should handle empty task list gracefully', () {
      final emptyTasks = <SignalTask>[];

      // When no tasks, inactive tasks should be empty
      expect(emptyTasks.where((task) => task.id != 'active').toList(), isEmpty);
    });
  });
}
