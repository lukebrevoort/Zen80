import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/signal_task.dart';
import 'package:signal_noise/models/time_slot.dart';
import 'package:signal_noise/models/sub_task.dart';

class _TestSignalTask extends SignalTask {
  _TestSignalTask({
    required super.id,
    required super.title,
    required super.estimatedMinutes,
    required super.scheduledDate,
    required super.createdAt,
    super.tagIds,
    super.subTasks,
    super.status,
    super.timeSlots,
    super.googleCalendarEventId,
    super.isComplete,
    super.rolledFromTaskId,
    super.remainingMinutesFromRollover,
  });

  @override
  Future<void> save() async {
    // Tests treat models as pure data; no Hive box.
  }
}

void main() {
  group('SignalTask Model', () {
    late DateTime today;
    late DateTime now;

    setUp(() {
      today = DateTime(2026, 1, 5);
      now = DateTime(2026, 1, 5, 10, 0);
    });

    SignalTask createTestTask({
      String id = 'task-1',
      String title = 'Test Task',
      int estimatedMinutes = 120,
      List<TimeSlot>? timeSlots,
      List<SubTask>? subTasks,
      List<String>? tagIds,
      TaskStatus status = TaskStatus.notStarted,
      bool isComplete = false,
    }) {
      return _TestSignalTask(
        id: id,
        title: title,
        estimatedMinutes: estimatedMinutes,
        scheduledDate: today,
        createdAt: now,
        timeSlots: timeSlots,
        subTasks: subTasks,
        tagIds: tagIds,
        status: status,
        isComplete: isComplete,
      );
    }

    TimeSlot createTestSlot({
      String id = 'slot-1',
      int durationMinutes = 60,
      int accumulatedSeconds = 0,
      bool isActive = false,
      bool isDiscarded = false,
    }) {
      final start = DateTime(2026, 1, 5, 9, 0);
      return TimeSlot(
        id: id,
        plannedStartTime: start,
        plannedEndTime: start.add(Duration(minutes: durationMinutes)),
        accumulatedSeconds: accumulatedSeconds,
        isActive: isActive,
        isDiscarded: isDiscarded,
      );
    }

    group('Scheduling - Time Slot Management', () {
      test('isScheduled returns false when no time slots', () {
        final task = createTestTask();
        expect(task.isScheduled, isFalse);
      });

      test('isScheduled returns true when has time slots', () {
        final task = createTestTask(timeSlots: [createTestSlot()]);
        expect(task.isScheduled, isTrue);
      });

      test('scheduledMinutes sums all non-discarded slot durations', () {
        final task = createTestTask(
          timeSlots: [
            createTestSlot(id: 'slot-1', durationMinutes: 60),
            createTestSlot(id: 'slot-2', durationMinutes: 30),
          ],
        );
        expect(task.scheduledMinutes, equals(90));
      });

      test('scheduledMinutes excludes discarded slots', () {
        final task = createTestTask(
          timeSlots: [
            createTestSlot(id: 'slot-1', durationMinutes: 60),
            createTestSlot(
              id: 'slot-2',
              durationMinutes: 30,
              isDiscarded: true,
            ),
          ],
        );
        expect(task.scheduledMinutes, equals(60));
      });

      test('unscheduledMinutes calculates remaining time correctly', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 60)],
        );
        expect(task.unscheduledMinutes, equals(60));
      });

      test('unscheduledMinutes returns 0 when fully scheduled', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 60)],
        );
        expect(task.unscheduledMinutes, equals(0));
      });

      test('unscheduledMinutes returns 0 when over-scheduled', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 90)],
        );
        expect(task.unscheduledMinutes, equals(0));
      });
    });

    group('Time Slot Splitting', () {
      test('isFullyScheduled when all time scheduled', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [
            createTestSlot(id: 'slot-1', durationMinutes: 60),
            createTestSlot(id: 'slot-2', durationMinutes: 60),
          ],
        );
        expect(task.isFullyScheduled, isTrue);
        expect(task.isPartiallyScheduled, isFalse);
      });

      test('isPartiallyScheduled when some time scheduled', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 60)],
        );
        expect(task.isPartiallyScheduled, isTrue);
        expect(task.isFullyScheduled, isFalse);
      });

      test('scheduledPercentage calculates correctly', () {
        final task = createTestTask(
          estimatedMinutes: 100,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 75)],
        );
        expect(task.scheduledPercentage, equals(0.75));
      });

      test('scheduledPercentage clamps to 1.0 when over-scheduled', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 90)],
        );
        expect(task.scheduledPercentage, equals(1.0));
      });

      test('formattedScheduledTime formats correctly', () {
        final task = createTestTask(
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 90)],
        );
        expect(task.formattedScheduledTime, equals('1h 30m'));
      });

      test('formattedUnscheduledTime shows remaining', () {
        final task = createTestTask(
          estimatedMinutes: 180,
          timeSlots: [createTestSlot(id: 'slot-1', durationMinutes: 60)],
        );
        expect(task.formattedUnscheduledTime, equals('2h'));
      });
    });

    group('Actual Time Tracking', () {
      test('actualMinutes sums all slot accumulated times', () {
        final task = createTestTask(
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 1800), // 30 min
            createTestSlot(id: 'slot-2', accumulatedSeconds: 2700), // 45 min
          ],
        );
        expect(task.actualMinutes, equals(75));
      });

      test('progressPercentage calculates actual vs estimated', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 3600), // 60 min
          ],
        );
        expect(task.progressPercentage, equals(0.5));
      });

      test('remainingMinutes calculates correctly', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 2700), // 45 min
          ],
        );
        expect(task.remainingMinutes, equals(75));
      });

      test('remainingMinutes returns 0 when exceeded', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 5400), // 90 min
          ],
        );
        expect(task.remainingMinutes, equals(0));
      });
    });

    group('Active Time Slot', () {
      test('hasActiveTimeSlot returns false when no active slots', () {
        final task = createTestTask(
          timeSlots: [createTestSlot(isActive: false)],
        );
        expect(task.hasActiveTimeSlot, isFalse);
      });

      test('hasActiveTimeSlot returns true when slot is active', () {
        final task = createTestTask(
          timeSlots: [createTestSlot(isActive: true)],
        );
        expect(task.hasActiveTimeSlot, isTrue);
      });

      test('activeTimeSlot returns the active slot', () {
        final activeSlot = createTestSlot(id: 'active-slot', isActive: true);
        final task = createTestTask(
          timeSlots: [
            createTestSlot(id: 'slot-1', isActive: false),
            activeSlot,
          ],
        );
        expect(task.activeTimeSlot?.id, equals('active-slot'));
      });

      test('activeTimeSlot returns null when no active slot', () {
        final task = createTestTask(
          timeSlots: [createTestSlot(isActive: false)],
        );
        expect(task.activeTimeSlot, isNull);
      });
    });

    group('SubTask Management', () {
      test('completedSubTaskCount counts checked subtasks', () {
        final task = createTestTask(
          subTasks: [
            SubTask(id: 'st-1', title: 'SubTask 1', isChecked: true),
            SubTask(id: 'st-2', title: 'SubTask 2', isChecked: false),
            SubTask(id: 'st-3', title: 'SubTask 3', isChecked: true),
          ],
        );
        expect(task.completedSubTaskCount, equals(2));
      });

      test('subTaskProgressPercentage calculates correctly', () {
        final task = createTestTask(
          subTasks: [
            SubTask(id: 'st-1', title: 'SubTask 1', isChecked: true),
            SubTask(id: 'st-2', title: 'SubTask 2', isChecked: false),
            SubTask(id: 'st-3', title: 'SubTask 3', isChecked: false),
            SubTask(id: 'st-4', title: 'SubTask 4', isChecked: false),
          ],
        );
        expect(task.subTaskProgressPercentage, equals(0.25));
      });

      test('subTaskProgressPercentage returns 1.0 for no subtasks', () {
        final task = createTestTask(subTasks: []);
        expect(task.subTaskProgressPercentage, equals(1.0));
      });

      test('addSubTask adds subtask to list', () {
        final task = createTestTask();
        task.addSubTask(SubTask(id: 'st-1', title: 'New SubTask'));

        expect(task.subTasks.length, equals(1));
        expect(task.subTasks.first.title, equals('New SubTask'));
      });

      test('removeSubTask removes subtask and unlinks from slots', () {
        final task = createTestTask(
          subTasks: [
            SubTask(
              id: 'st-1',
              title: 'SubTask 1',
              linkedTimeSlotIds: ['slot-1'],
            ),
          ],
          timeSlots: [
            TimeSlot(
              id: 'slot-1',
              plannedStartTime: DateTime(2026, 1, 5, 9, 0),
              plannedEndTime: DateTime(2026, 1, 5, 10, 0),
              linkedSubTaskIds: ['st-1'],
            ),
          ],
        );

        task.removeSubTask('st-1');

        expect(task.subTasks.isEmpty, isTrue);
        expect(task.timeSlots.first.linkedSubTaskIds.contains('st-1'), isFalse);
      });

      test('toggleSubTask toggles checked state', () {
        final task = createTestTask(
          subTasks: [SubTask(id: 'st-1', title: 'SubTask 1', isChecked: false)],
        );

        task.toggleSubTask('st-1');
        expect(task.subTasks.first.isChecked, isTrue);

        task.toggleSubTask('st-1');
        expect(task.subTasks.first.isChecked, isFalse);
      });
    });

    group('Tag Management', () {
      test('addTag adds unique tag', () {
        final task = createTestTask(tagIds: ['tag-1']);
        task.addTag('tag-2');

        expect(task.tagIds.length, equals(2));
        expect(task.tagIds, contains('tag-2'));
      });

      test('addTag does not add duplicate', () {
        final task = createTestTask(tagIds: ['tag-1']);
        task.addTag('tag-1');

        expect(task.tagIds.length, equals(1));
      });

      test('removeTag removes tag', () {
        final task = createTestTask(tagIds: ['tag-1', 'tag-2']);
        task.removeTag('tag-1');

        expect(task.tagIds, isNot(contains('tag-1')));
        expect(task.tagIds, contains('tag-2'));
      });
    });

    group('Task Status', () {
      test('markComplete sets correct status', () {
        final task = createTestTask();
        task.markComplete();

        expect(task.isComplete, isTrue);
        expect(task.status, equals(TaskStatus.completed));
      });

      test('markRolled sets status to rolled', () {
        final task = createTestTask();
        task.markRolled();

        expect(task.status, equals(TaskStatus.rolled));
      });

      test('isRollover returns true when rolled from another task', () {
        final task = createTestTask();
        final rolloverTask = task.copyWith(
          rolledFromTaskId: 'original-task-id',
        );

        expect(rolloverTask.isRollover, isTrue);
      });

      test('isRollover returns false for new tasks', () {
        final task = createTestTask();
        expect(task.isRollover, isFalse);
      });
    });

    group('Commitment Threshold', () {
      test('returns 5 minutes for tasks under 2 hours', () {
        final task = createTestTask(estimatedMinutes: 90);
        expect(task.commitmentThreshold, equals(const Duration(minutes: 5)));
      });

      test('returns 10 minutes for tasks 2+ hours', () {
        final task = createTestTask(estimatedMinutes: 120);
        expect(task.commitmentThreshold, equals(const Duration(minutes: 10)));
      });

      test('returns 10 minutes for long tasks', () {
        final task = createTestTask(estimatedMinutes: 300);
        expect(task.commitmentThreshold, equals(const Duration(minutes: 10)));
      });

      test('slotMeetsCommitmentThreshold validates correctly', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 360), // 6 min
          ],
        );
        expect(task.slotMeetsCommitmentThreshold('slot-1'), isTrue);
      });

      test('slotMeetsCommitmentThreshold fails for short sessions', () {
        final task = createTestTask(
          estimatedMinutes: 60,
          timeSlots: [
            createTestSlot(id: 'slot-1', accumulatedSeconds: 180), // 3 min
          ],
        );
        expect(task.slotMeetsCommitmentThreshold('slot-1'), isFalse);
      });
    });

    group('Session Management', () {
      test('lastStoppedSlot returns most recently stopped slot', () {
        final earlierStop = DateTime(2026, 1, 5, 10, 0);
        final laterStop = DateTime(2026, 1, 5, 11, 0);

        final task = createTestTask(
          timeSlots: [
            TimeSlot(
              id: 'slot-1',
              plannedStartTime: DateTime(2026, 1, 5, 9, 0),
              plannedEndTime: DateTime(2026, 1, 5, 10, 0),
              lastStopTime: earlierStop,
              isActive: false,
            ),
            TimeSlot(
              id: 'slot-2',
              plannedStartTime: DateTime(2026, 1, 5, 11, 0),
              plannedEndTime: DateTime(2026, 1, 5, 12, 0),
              lastStopTime: laterStop,
              isActive: false,
            ),
          ],
        );

        expect(task.lastStoppedSlot?.id, equals('slot-2'));
      });

      test('lastStoppedSlot excludes discarded slots', () {
        final task = createTestTask(
          timeSlots: [
            TimeSlot(
              id: 'slot-1',
              plannedStartTime: DateTime(2026, 1, 5, 9, 0),
              plannedEndTime: DateTime(2026, 1, 5, 10, 0),
              lastStopTime: DateTime(2026, 1, 5, 10, 0),
              isActive: false,
            ),
            TimeSlot(
              id: 'slot-2',
              plannedStartTime: DateTime(2026, 1, 5, 11, 0),
              plannedEndTime: DateTime(2026, 1, 5, 12, 0),
              lastStopTime: DateTime(2026, 1, 5, 12, 0),
              isActive: false,
              isDiscarded: true,
            ),
          ],
        );

        expect(task.lastStoppedSlot?.id, equals('slot-1'));
      });

      test('shouldCreateNewSlotOnResume returns true for large gaps', () {
        final task = createTestTask(
          timeSlots: [
            TimeSlot(
              id: 'slot-1',
              plannedStartTime: DateTime(2026, 1, 5, 9, 0),
              plannedEndTime: DateTime(2026, 1, 5, 10, 0),
              lastStopTime: DateTime.now().subtract(
                const Duration(minutes: 20),
              ),
              isActive: false,
            ),
          ],
        );

        expect(task.shouldCreateNewSlotOnResume, isTrue);
      });

      test('shouldCreateNewSlotOnResume returns false for small gaps', () {
        final task = createTestTask(
          timeSlots: [
            TimeSlot(
              id: 'slot-1',
              plannedStartTime: DateTime(2026, 1, 5, 9, 0),
              plannedEndTime: DateTime(2026, 1, 5, 10, 0),
              lastStopTime: DateTime.now().subtract(
                const Duration(minutes: 10),
              ),
              isActive: false,
            ),
          ],
        );

        expect(task.shouldCreateNewSlotOnResume, isFalse);
      });

      test(
        'startTimeSlot throws when resuming after merge window even if calendar-linked',
        () {
          final task = createTestTask(
            timeSlots: [
              TimeSlot(
                id: 'slot-1',
                plannedStartTime: DateTime(2026, 1, 5, 9, 0),
                plannedEndTime: DateTime(2026, 1, 5, 10, 0),
                sessionStartTime: DateTime(2026, 1, 5, 9, 0),
                lastStopTime: DateTime.now().subtract(
                  const Duration(minutes: 20),
                ),
                externalCalendarEventId: 'external-123',
                isActive: false,
              ),
            ],
          );

          expect(
            () => task.startTimeSlot('slot-1'),
            throwsA(isA<StateError>()),
          );
        },
      );

      test(
        'startTimeSlot resumes within merge window and preserves sessionStartTime',
        () {
          final initialSessionStartTime = DateTime(2026, 1, 5, 9, 0);
          final task = createTestTask(
            timeSlots: [
              TimeSlot(
                id: 'slot-1',
                plannedStartTime: DateTime(2026, 1, 5, 9, 0),
                plannedEndTime: DateTime(2026, 1, 5, 10, 0),
                sessionStartTime: initialSessionStartTime,
                lastStopTime: DateTime.now().subtract(
                  const Duration(minutes: 10),
                ),
                externalCalendarEventId: 'external-123',
                isActive: false,
              ),
            ],
          );

          task.startTimeSlot('slot-1');

          final slot = task.timeSlots.first;
          expect(slot.isActive, isTrue);
          expect(slot.sessionStartTime, equals(initialSessionStartTime));
        },
      );
    });

    group('Formatted Output', () {
      test('formattedEstimatedTime formats hours and minutes', () {
        final task = createTestTask(estimatedMinutes: 150);
        expect(task.formattedEstimatedTime, equals('2h 30m'));
      });

      test('formattedEstimatedTime formats hours only', () {
        final task = createTestTask(estimatedMinutes: 180);
        expect(task.formattedEstimatedTime, equals('3h'));
      });

      test('formattedEstimatedTime formats minutes only', () {
        final task = createTestTask(estimatedMinutes: 45);
        expect(task.formattedEstimatedTime, equals('45m'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final task = createTestTask(title: 'Original');
        final copy = task.copyWith(title: 'Updated');

        expect(copy.title, equals('Updated'));
        expect(task.title, equals('Original')); // Original unchanged
      });

      test('clearGoogleCalendarEventId works correctly', () {
        final task = createTestTask();
        final withEventId = task.copyWith(googleCalendarEventId: 'event-123');
        final cleared = withEventId.copyWith(clearGoogleCalendarEventId: true);

        expect(cleared.googleCalendarEventId, isNull);
      });

      test('clearRolledFromTaskId works correctly', () {
        final task = createTestTask();
        final withRollover = task.copyWith(rolledFromTaskId: 'original-task');
        final cleared = withRollover.copyWith(clearRolledFromTaskId: true);

        expect(cleared.rolledFromTaskId, isNull);
      });
    });

    group('Equality', () {
      test('tasks with same id are equal', () {
        final task1 = createTestTask(id: 'task-1', title: 'Task A');
        final task2 = createTestTask(id: 'task-1', title: 'Task B');

        expect(task1, equals(task2));
      });

      test('tasks with different ids are not equal', () {
        final task1 = createTestTask(id: 'task-1');
        final task2 = createTestTask(id: 'task-2');

        expect(task1, isNot(equals(task2)));
      });
    });

    group('Calendar Presence - Pre-scheduled vs Ad-hoc Slots', () {
      test('hasCalendarPresence returns true for non-discarded slots', () {
        final task = createTestTask(
          timeSlots: [createTestSlot(id: 'slot-1', isDiscarded: false)],
        );

        expect(task.hasCalendarPresence, isTrue);
      });

      test('hasCalendarPresence returns false when all slots discarded', () {
        final task = createTestTask(
          timeSlots: [
            createTestSlot(id: 'slot-1', isDiscarded: true),
            createTestSlot(id: 'slot-2', isDiscarded: true),
          ],
        );

        expect(task.hasCalendarPresence, isFalse);
      });

      test(
        'hasCalendarPresence returns true when at least one slot not discarded',
        () {
          final task = createTestTask(
            timeSlots: [
              createTestSlot(id: 'slot-1', isDiscarded: true),
              createTestSlot(
                id: 'slot-2',
                isDiscarded: false,
              ), // This one keeps presence
            ],
          );

          expect(task.hasCalendarPresence, isTrue);
        },
      );

      test('hasCalendarPresence returns false with no slots', () {
        final task = createTestTask(timeSlots: []);
        expect(task.hasCalendarPresence, isFalse);
      });

      test('pre-scheduled slot reset under threshold keeps calendar presence', () {
        // Simulates the scenario: user starts pre-scheduled slot, stops under 5 min
        // The slot should be reset (not discarded) so task keeps calendar presence
        final start = DateTime(2026, 1, 5, 9, 0);
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: start,
          plannedEndTime: start.add(const Duration(minutes: 60)),
          googleCalendarEventId:
              'gcal-event-123', // Pre-scheduled from "Start My Day"
          // After reset (under threshold), these are cleared:
          accumulatedSeconds: 0,
          isActive: false,
          isDiscarded: false, // KEY: NOT discarded!
        );

        final task = createTestTask(timeSlots: [slot]);

        // Task should still have calendar presence
        expect(task.hasCalendarPresence, isTrue);
        expect(task.timeSlots.first.isDiscarded, isFalse);
        expect(
          task.timeSlots.first.googleCalendarEventId,
          equals('gcal-event-123'),
        );
      });

      test(
        'ad-hoc slot discarded under threshold removes calendar presence',
        () {
          // Simulates the scenario: user starts ad-hoc slot, stops under 5 min
          // The slot should be discarded so task loses calendar presence
          final start = DateTime(2026, 1, 5, 9, 0);
          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: start,
            plannedEndTime: start.add(const Duration(minutes: 60)),
            // No googleCalendarEventId = was ad-hoc
            accumulatedSeconds: 0,
            isActive: false,
            isDiscarded: true, // Discarded under threshold
          );

          final task = createTestTask(timeSlots: [slot]);

          // Task should NOT have calendar presence
          expect(task.hasCalendarPresence, isFalse);
          expect(task.timeSlots.first.isDiscarded, isTrue);
        },
      );
    });

    group('needsScheduling - Interaction with Completed Work', () {
      test('needsScheduling false when slot has completed work', () {
        final task = createTestTask(
          estimatedMinutes: 120,
          timeSlots: [
            createTestSlot(
              id: 'slot-1',
              durationMinutes: 60,
              accumulatedSeconds: 1800, // 30 min of completed work
            ),
          ],
        );

        // User has done work, don't nag them to schedule more
        expect(task.needsScheduling, isFalse);
      });

      test('needsScheduling true when no slots', () {
        final task = createTestTask(timeSlots: []);
        expect(task.needsScheduling, isTrue);
      });

      test(
        'needsScheduling true when only discarded slots (no completed work)',
        () {
          final start = DateTime(2026, 1, 5, 9, 0);
          final task = createTestTask(
            estimatedMinutes: 120,
            timeSlots: [
              TimeSlot(
                id: 'slot-1',
                plannedStartTime: start,
                plannedEndTime: start.add(const Duration(minutes: 60)),
                isDiscarded: true,
                accumulatedSeconds: 0,
              ),
            ],
          );

          // Discarded slot with no work = needs scheduling
          expect(task.needsScheduling, isTrue);
        },
      );

      test(
        'needsScheduling false for pre-scheduled reset slot (not discarded)',
        () {
          // Pre-scheduled slot that was reset under threshold
          // isDiscarded = false means it counts toward scheduling
          final start = DateTime(2026, 1, 5, 9, 0);
          final task = createTestTask(
            estimatedMinutes: 60, // 1 hour task
            timeSlots: [
              TimeSlot(
                id: 'slot-1',
                plannedStartTime: start,
                plannedEndTime: start.add(const Duration(minutes: 60)),
                googleCalendarEventId: 'gcal-event-123',
                isDiscarded: false, // Reset, not discarded
                accumulatedSeconds: 0, // No work yet
              ),
            ],
          );

          // Slot is not discarded, so scheduledMinutes = 60, which covers estimated
          // But there's no completed work, so we check unscheduledMinutes
          expect(task.scheduledMinutes, equals(60));
          expect(task.unscheduledMinutes, equals(0)); // Fully covered
          expect(task.needsScheduling, isFalse); // Fully scheduled
        },
      );
    });
  });
}
