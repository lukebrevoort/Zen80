import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/time_slot.dart';

void main() {
  group('TimeSlot Model', () {
    late DateTime now;
    late DateTime plannedStart;
    late DateTime plannedEnd;

    setUp(() {
      now = DateTime(2026, 1, 5, 9, 0); // 9:00 AM on Jan 5, 2026
      plannedStart = DateTime(2026, 1, 5, 9, 0);
      plannedEnd = DateTime(2026, 1, 5, 11, 0); // 2 hour slot
    });

    group('Planned Duration', () {
      test('calculates planned duration correctly', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        expect(slot.plannedDuration, equals(const Duration(hours: 2)));
      });

      test('handles 30 minute slots', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedStart.add(const Duration(minutes: 30)),
        );

        expect(slot.plannedDuration, equals(const Duration(minutes: 30)));
      });

      test('handles multi-hour slots', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedStart.add(
            const Duration(hours: 5, minutes: 15),
          ),
        );

        expect(
          slot.plannedDuration,
          equals(const Duration(hours: 5, minutes: 15)),
        );
      });
    });

    group('Actual Duration with Accumulated Time', () {
      test('returns zero when not started', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        expect(slot.actualDuration, equals(Duration.zero));
        expect(slot.hasStarted, isFalse);
      });

      test('returns accumulated seconds when stopped', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          accumulatedSeconds: 1800, // 30 minutes
          isActive: false,
        );

        expect(slot.actualDuration.inMinutes, equals(30));
      });

      test('does not include gap time in actual duration', () {
        // Scenario: User worked 10 min, took 5 min break, worked 10 more
        // Accumulated should only be 20 min, not 25
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          accumulatedSeconds: 1200, // 20 minutes of actual work
          isActive: false,
        );

        expect(slot.actualDuration.inMinutes, equals(20));
      });
    });

    group('Time Slot Status', () {
      test('returns scheduled status for future slots', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: DateTime.now().add(const Duration(hours: 2)),
          plannedEndTime: DateTime.now().add(const Duration(hours: 4)),
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.scheduled));
        expect(slot.isFuture, isTrue);
      });

      test('returns active status when timer is running', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now(),
          isActive: true,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.active));
      });

      test('returns completed status when stopped with work time', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          accumulatedSeconds: 3600, // 1 hour of work
          isActive: false,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.completed));
        expect(slot.isCompleted, isTrue);
      });

      test('returns missed status for past slots never started', () {
        final pastStart = DateTime.now().subtract(const Duration(hours: 3));
        final pastEnd = DateTime.now().subtract(const Duration(hours: 1));

        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: pastStart,
          plannedEndTime: pastEnd,
          accumulatedSeconds: 0,
          isActive: false,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.missed));
        expect(slot.isPast, isTrue);
        expect(slot.hasStarted, isFalse);
      });

      test('returns discarded status when marked discarded', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          isDiscarded: true,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.discarded));
      });
    });

    group('Session Management - Gap Handling', () {
      test('canMergeSession returns true for gap under 15 minutes', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          lastStopTime: DateTime.now().subtract(const Duration(minutes: 10)),
        );

        expect(slot.canMergeSession, isTrue);
      });

      test('canMergeSession returns false for gap over 15 minutes', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          lastStopTime: DateTime.now().subtract(const Duration(minutes: 20)),
        );

        expect(slot.canMergeSession, isFalse);
      });

      test('canMergeSession returns false when never stopped', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          lastStopTime: null,
        );

        expect(slot.canMergeSession, isFalse);
      });

      test('session merge threshold is exactly 15 minutes', () {
        expect(
          TimeSlot.sessionMergeThreshold,
          equals(const Duration(minutes: 15)),
        );
      });
    });

    group('Predicted vs Actual Times (Calendar Sync)', () {
      test('calendarStartTime returns planned when not started', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        expect(slot.calendarStartTime, equals(plannedStart));
      });

      test('calendarStartTime returns session start when finalized', () {
        // A finalized session should show its actual session start time
        final sessionStart = DateTime.now().subtract(const Duration(hours: 2));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: sessionStart,
          actualEndTime: sessionStart.add(const Duration(hours: 1)),
          sessionStartTime: sessionStart,
          accumulatedSeconds: 3600, // 1 hour of work (required for isCompleted)
          lastStopTime: DateTime.now().subtract(
            const Duration(minutes: 20),
          ), // Past merge window
          isActive: false,
        );

        expect(slot.isSessionFinalized, isTrue);
        expect(slot.calendarStartTime, equals(sessionStart));
      });

      test(
        'calendarEndTime returns planned when active and within planned time',
        () {
          // Use future dates to test the "within planned time" scenario
          final futureStart = DateTime.now().add(const Duration(minutes: 5));
          final futureEnd = DateTime.now().add(const Duration(hours: 2));
          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: futureStart,
            plannedEndTime: futureEnd,
            actualStartTime: DateTime.now(),
            isActive: true,
          );

          // Active slot within planned time should show planned end
          expect(slot.calendarEndTime, equals(futureEnd));
        },
      );

      test(
        'calendarEndTime returns current time when active and past planned end (overtime)',
        () {
          // Use past dates to test the "overtime" scenario
          final pastStart = DateTime.now().subtract(const Duration(hours: 3));
          final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: pastStart,
            plannedEndTime: pastEnd,
            actualStartTime: pastStart,
            isActive: true,
          );

          // Active slot past planned end should show current time (overtime)
          final calendarEnd = slot.calendarEndTime;
          final now = DateTime.now();
          // Should be within a few seconds of now
          expect(calendarEnd.difference(now).inSeconds.abs(), lessThan(5));
        },
      );

      test('calendarEndTime returns actual when session is finalized', () {
        // A finalized session should show its actual end time
        final actualEnd = DateTime.now().subtract(const Duration(hours: 1));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: plannedStart,
          actualEndTime: actualEnd,
          accumulatedSeconds: 1800, // Required for isCompleted
          lastStopTime: DateTime.now().subtract(
            const Duration(minutes: 20),
          ), // Past merge window
          isActive: false,
        );

        expect(slot.isSessionFinalized, isTrue);
        expect(slot.calendarEndTime, equals(actualEnd));
      });

      test('startVariance calculates late start correctly', () {
        final actualStart = plannedStart.add(const Duration(minutes: 15));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: actualStart,
        );

        expect(slot.startVariance, equals(const Duration(minutes: 15)));
        expect(slot.formattedStartVariance, equals('+15m late'));
      });

      test('startVariance calculates early start correctly', () {
        final actualStart = plannedStart.subtract(const Duration(minutes: 10));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: actualStart,
        );

        expect(slot.startVariance.inMinutes, equals(-10));
        expect(slot.formattedStartVariance, equals('10m early'));
      });

      test('startVariance shows on time for small differences', () {
        final actualStart = plannedStart.add(const Duration(minutes: 1));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: actualStart,
        );

        expect(slot.formattedStartVariance, equals('on time'));
      });

      test('actualDiffersFromPlanned detects significant variance', () {
        final actualStart = plannedStart.add(const Duration(minutes: 10));
        final actualEnd = plannedEnd.add(const Duration(minutes: 20));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: actualStart,
          actualEndTime: actualEnd,
        );

        expect(slot.actualDiffersFromPlanned, isTrue);
      });

      test('actualDiffersFromPlanned returns false for minor variance', () {
        final actualStart = plannedStart.add(const Duration(minutes: 2));
        final actualEnd = plannedEnd.add(const Duration(minutes: 3));
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: actualStart,
          actualEndTime: actualEnd,
        );

        expect(slot.actualDiffersFromPlanned, isFalse);
      });
    });

    group('Timer Operations', () {
      test('start() sets actualStartTime and sessionStartTime', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        slot.start();

        expect(slot.isActive, isTrue);
        expect(slot.actualStartTime, isNotNull);
        expect(slot.sessionStartTime, isNotNull);
        expect(slot.isDiscarded, isFalse);
      });

      test('end() accumulates session time', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now().subtract(const Duration(minutes: 30)),
          isActive: true,
          accumulatedSeconds: 0,
        );

        slot.end();

        expect(slot.isActive, isFalse);
        expect(slot.actualEndTime, isNotNull);
        expect(slot.lastStopTime, isNotNull);
        // Should have accumulated ~30 minutes
        expect(slot.accumulatedSeconds, greaterThan(1500)); // At least 25 mins
      });

      test('discard() resets all session data', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now(),
          sessionStartTime: DateTime.now(),
          accumulatedSeconds: 300,
          isActive: true,
        );

        slot.discard();

        expect(slot.isDiscarded, isTrue);
        expect(slot.accumulatedSeconds, equals(0));
        expect(slot.actualStartTime, isNull);
        expect(slot.actualEndTime, isNull);
        expect(slot.sessionStartTime, isNull);
        expect(slot.isActive, isFalse);
      });

      test('continueTimer() disables autoEnd', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          autoEnd: true,
        );

        slot.continueTimer();

        expect(slot.wasManualContinue, isTrue);
        expect(slot.autoEnd, isFalse);
      });
    });

    group('Session Finalization - BOTH conditions required', () {
      test(
        'isSessionFinalized returns false when only past merge window (not past planned end)',
        () {
          // User worked and stopped, but we're still within planned time
          // e.g., planned 2-4 PM, user worked 2:00-2:30, stopped, it's now 2:50 PM
          final futureEnd = DateTime.now().add(const Duration(hours: 1));
          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: DateTime.now().subtract(const Duration(hours: 1)),
            plannedEndTime: futureEnd, // Planned end is in the future
            accumulatedSeconds:
                1800, // 30 min of work (required for isCompleted)
            isActive: false,
            lastStopTime: DateTime.now().subtract(
              const Duration(minutes: 20),
            ), // Past merge window
          );

          // Merge window expired (!canMergeSession), but planned end not reached
          expect(slot.canMergeSession, isFalse);
          expect(slot.isSessionFinalized, isFalse); // Should NOT be finalized
        },
      );

      test(
        'isSessionFinalized returns false when only past planned end (still in merge window)',
        () {
          // User is working overtime - past planned end but still actively working/pauseable
          // e.g., planned 2-3 PM, user worked 2:00-3:20, stopped 5 min ago
          final pastEnd = DateTime.now().subtract(const Duration(minutes: 20));
          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: DateTime.now().subtract(const Duration(hours: 2)),
            plannedEndTime: pastEnd, // Planned end is in the past (20 min ago)
            accumulatedSeconds: 7200, // 2 hours of work
            isActive: false,
            lastStopTime: DateTime.now().subtract(
              const Duration(minutes: 5),
            ), // Still in merge window
          );

          // Past planned end + 15 min, but still in merge window
          expect(slot.canMergeSession, isTrue);
          expect(slot.isSessionFinalized, isFalse); // Should NOT be finalized
        },
      );

      test('isSessionFinalized returns true when BOTH conditions met', () {
        // Session is truly done: past planned end AND merge window expired
        // e.g., planned 2-3 PM, user worked 2:00-3:00, stopped 20 min ago, now 3:20 PM
        final pastEnd = DateTime.now().subtract(
          const Duration(minutes: 20),
        ); // plannedEnd + 15 < now
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: DateTime.now().subtract(const Duration(hours: 2)),
          plannedEndTime: pastEnd, // 20 min ago
          accumulatedSeconds: 3600, // 1 hour of work
          isActive: false,
          lastStopTime: DateTime.now().subtract(
            const Duration(minutes: 20),
          ), // Past merge window
          sessionStartTime: DateTime.now().subtract(const Duration(hours: 2)),
          actualEndTime: pastEnd,
        );

        // Both conditions met
        expect(slot.canMergeSession, isFalse);
        expect(
          DateTime.now().isAfter(
            slot.plannedEndTime.add(TimeSlot.sessionMergeThreshold),
          ),
          isTrue,
        );
        expect(slot.isSessionFinalized, isTrue); // SHOULD be finalized
      });

      test('isSessionFinalized returns false when not completed', () {
        // Slot was never worked on
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: DateTime.now().subtract(const Duration(hours: 3)),
          plannedEndTime: DateTime.now().subtract(const Duration(hours: 1)),
          accumulatedSeconds: 0, // No work
          isActive: false,
        );

        expect(slot.isCompleted, isFalse);
        expect(slot.isSessionFinalized, isFalse);
      });

      test('isSessionFinalized returns false when lastStopTime is null', () {
        // Slot has accumulated work but no lastStopTime (shouldn't happen but edge case)
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: DateTime.now().subtract(const Duration(hours: 3)),
          plannedEndTime: DateTime.now().subtract(const Duration(hours: 1)),
          accumulatedSeconds: 1800,
          isActive: false,
          lastStopTime: null,
        );

        expect(slot.isCompleted, isTrue);
        expect(slot.isSessionFinalized, isFalse);
      });
    });

    group('Pre-scheduled vs Ad-hoc Slot Identification', () {
      test('slot with googleCalendarEventId is pre-scheduled', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          googleCalendarEventId: 'gcal-event-123',
        );

        // Pre-scheduled slots have a calendar event ID from "Start My Day"
        expect(slot.googleCalendarEventId, isNotNull);
        expect(slot.externalCalendarEventId, isNull);
        expect(slot.isSyncedToCalendar, isTrue);
      });

      test('slot with externalCalendarEventId is pre-scheduled (imported)', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          externalCalendarEventId: 'external-event-456',
        );

        // Imported external events are also considered "pre-scheduled"
        expect(slot.externalCalendarEventId, isNotNull);
        expect(slot.googleCalendarEventId, isNull);
        expect(slot.isImportedFromExternal, isTrue);
      });

      test('slot without calendar event IDs is ad-hoc', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        // Ad-hoc slots have no calendar event IDs
        expect(slot.googleCalendarEventId, isNull);
        expect(slot.externalCalendarEventId, isNull);
        expect(slot.isSyncedToCalendar, isFalse);
        expect(slot.isImportedFromExternal, isFalse);
      });
    });

    group('Commitment Threshold - Pre-scheduled vs Ad-hoc Behavior', () {
      // These tests verify the slot state AFTER stopTimeSlot() processes them.
      // The actual logic is in SignalTaskProvider.stopTimeSlot(), but we test
      // the expected end states here at the model level.

      test('ad-hoc slot under threshold: should be discarded (cleared)', () {
        // Simulate what stopTimeSlot() does to an ad-hoc slot under threshold
        final adHocSlot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now().subtract(const Duration(minutes: 3)),
          sessionStartTime: DateTime.now().subtract(const Duration(minutes: 3)),
          accumulatedSeconds: 180, // 3 minutes (under 5 min threshold)
          isActive: true,
          // No calendar event ID = ad-hoc
        );

        // Simulate stopTimeSlot() behavior for ad-hoc under threshold
        final discardedSlot = adHocSlot.copyWith(
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

        // Verify expected state after discard
        expect(discardedSlot.isDiscarded, isTrue);
        expect(discardedSlot.accumulatedSeconds, equals(0));
        expect(discardedSlot.actualStartTime, isNull);
        expect(discardedSlot.sessionStartTime, isNull);
        expect(discardedSlot.displayStatus, equals(TimeSlotStatus.discarded));
      });

      test('pre-scheduled slot under threshold: should reset but NOT discard', () {
        // Use FUTURE dates to ensure displayStatus returns 'scheduled' after reset
        final futurePlannedStart = DateTime.now().add(const Duration(hours: 1));
        final futurePlannedEnd = DateTime.now().add(const Duration(hours: 3));

        // Simulate what stopTimeSlot() does to a pre-scheduled slot under threshold
        final preScheduledSlot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: futurePlannedStart,
          plannedEndTime: futurePlannedEnd,
          actualStartTime: DateTime.now().subtract(const Duration(minutes: 3)),
          sessionStartTime: DateTime.now().subtract(const Duration(minutes: 3)),
          accumulatedSeconds: 180, // 3 minutes (under 5 min threshold)
          isActive: true,
          googleCalendarEventId:
              'gcal-event-123', // Has calendar event = pre-scheduled
        );

        // Simulate stopTimeSlot() behavior for pre-scheduled under threshold
        final resetSlot = preScheduledSlot.copyWith(
          isActive: false,
          clearActualStartTime: true,
          clearActualEndTime: true,
          clearSessionStartTime: true,
          clearLastStopTime: true,
          accumulatedSeconds: 0,
          isDiscarded: false, // KEY: NOT discarded!
          // googleCalendarEventId is KEPT (not cleared)
        );

        // Verify expected state after reset
        expect(resetSlot.isDiscarded, isFalse); // Still visible/scheduled
        expect(
          resetSlot.googleCalendarEventId,
          equals('gcal-event-123'),
        ); // Calendar event kept
        expect(resetSlot.accumulatedSeconds, equals(0)); // Session reset
        expect(resetSlot.actualStartTime, isNull); // Ready to try again
        expect(
          resetSlot.displayStatus,
          equals(TimeSlotStatus.scheduled),
        ); // Ready for use (future slot with no work)
      });

      test('pre-scheduled slot meeting threshold: normal completion', () {
        // Pre-scheduled slot that meets the 5-min threshold
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
          sessionStartTime: DateTime.now().subtract(
            const Duration(minutes: 10),
          ),
          accumulatedSeconds: 600, // 10 minutes (meets threshold)
          isActive: false,
          lastStopTime: DateTime.now(),
          actualEndTime: DateTime.now(),
          googleCalendarEventId: 'gcal-event-123',
        );

        // Slot should be completed, not discarded
        expect(slot.isDiscarded, isFalse);
        expect(slot.isCompleted, isTrue);
        expect(slot.displayStatus, equals(TimeSlotStatus.completed));
      });

      test('ad-hoc slot meeting threshold: normal completion', () {
        // Ad-hoc slot that meets the 5-min threshold
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
          sessionStartTime: DateTime.now().subtract(
            const Duration(minutes: 10),
          ),
          accumulatedSeconds: 600, // 10 minutes (meets threshold)
          isActive: false,
          lastStopTime: DateTime.now(),
          actualEndTime: DateTime.now(),
          // No calendar event ID = was ad-hoc, but now synced
        );

        // Slot should be completed, not discarded
        expect(slot.isDiscarded, isFalse);
        expect(slot.isCompleted, isTrue);
        expect(slot.displayStatus, equals(TimeSlotStatus.completed));
      });
    });

    group('External Calendar Events', () {
      test('isImportedFromExternal returns true for external events', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          externalCalendarEventId: 'google-event-123',
        );

        expect(slot.isImportedFromExternal, isTrue);
      });

      test('isImportedFromExternal returns false for Signal-created slots', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          googleCalendarEventId: 'signal-created-event',
        );

        expect(slot.isImportedFromExternal, isFalse);
        expect(slot.isSyncedToCalendar, isTrue);
      });
    });

    group('SubTask Linking', () {
      test('linkSubTask adds subtask to slot', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        slot.linkSubTask('subtask-1');

        expect(slot.linkedSubTaskIds, contains('subtask-1'));
      });

      test('linkSubTask does not add duplicates', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
        );

        slot.linkSubTask('subtask-1');
        slot.linkSubTask('subtask-1');

        expect(slot.linkedSubTaskIds.length, equals(1));
      });

      test('unlinkSubTask removes subtask from slot', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          linkedSubTaskIds: ['subtask-1', 'subtask-2'],
        );

        slot.unlinkSubTask('subtask-1');

        expect(slot.linkedSubTaskIds, isNot(contains('subtask-1')));
        expect(slot.linkedSubTaskIds, contains('subtask-2'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          isActive: false,
        );

        final copy = slot.copyWith(isActive: true);

        expect(copy.id, equals('slot-1'));
        expect(copy.isActive, isTrue);
        expect(slot.isActive, isFalse); // Original unchanged
      });

      test('clearActualStartTime works correctly', () {
        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: plannedStart,
          plannedEndTime: plannedEnd,
          actualStartTime: DateTime.now(),
        );

        final copy = slot.copyWith(clearActualStartTime: true);

        expect(copy.actualStartTime, isNull);
      });
    });

    group('Missed Slot Detection', () {
      test(
        'displayStatus is missed when past planned end and never started',
        () {
          // Slot scheduled for 2 hours ago, never started
          final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
          final pastStart = DateTime.now().subtract(const Duration(hours: 2));

          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: pastStart,
            plannedEndTime: pastEnd,
            accumulatedSeconds: 0, // Never worked
            sessionStartTime: null, // Never started
            isActive: false,
            isDiscarded: false,
          );

          expect(slot.displayStatus, equals(TimeSlotStatus.missed));
          expect(slot.hasStarted, isFalse);
          expect(slot.isPast, isTrue);
        },
      );

      test('displayStatus is NOT missed when has work (completed instead)', () {
        // Slot is past but has accumulated work
        final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
        final pastStart = DateTime.now().subtract(const Duration(hours: 2));

        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: pastStart,
          plannedEndTime: pastEnd,
          accumulatedSeconds: 1800, // 30 min of work
          sessionStartTime: pastStart,
          lastStopTime: pastEnd,
          isActive: false,
          isDiscarded: false,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.completed));
        expect(slot.hasStarted, isTrue);
      });

      test('displayStatus is discarded when marked as discarded', () {
        final pastEnd = DateTime.now().subtract(const Duration(hours: 1));
        final pastStart = DateTime.now().subtract(const Duration(hours: 2));

        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: pastStart,
          plannedEndTime: pastEnd,
          accumulatedSeconds: 0,
          isActive: false,
          isDiscarded: true, // Explicitly discarded
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.discarded));
      });

      test('displayStatus is scheduled for future unstarted slots', () {
        // Future slot
        final futureStart = DateTime.now().add(const Duration(hours: 1));
        final futureEnd = DateTime.now().add(const Duration(hours: 2));

        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: futureStart,
          plannedEndTime: futureEnd,
          accumulatedSeconds: 0,
          isActive: false,
        );

        expect(slot.displayStatus, equals(TimeSlotStatus.scheduled));
        expect(slot.isFuture, isTrue);
      });

      test(
        'slot eligible for cleanup: past planned+15min, never started, has calendar event',
        () {
          // This tests the criteria used by _shouldCleanupMissedSlot
          final now = DateTime.now();
          // 20 min past planned end (past the 15 min threshold)
          final pastEnd = now.subtract(const Duration(minutes: 20));
          final pastStart = now.subtract(const Duration(hours: 1, minutes: 20));

          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: pastStart,
            plannedEndTime: pastEnd,
            googleCalendarEventId: 'cal-event-123', // Has calendar event
            accumulatedSeconds: 0, // Never worked
            sessionStartTime: null, // Never started session
            isActive: false,
            isDiscarded: false,
            externalCalendarEventId: null, // Not imported
          );

          // Verify the cleanup conditions
          expect(slot.googleCalendarEventId, isNotNull);
          expect(slot.isDiscarded, isFalse);
          expect(slot.isImportedFromExternal, isFalse);
          expect(
            now.isAfter(
              slot.plannedEndTime.add(TimeSlot.sessionMergeThreshold),
            ),
            isTrue,
          );
          expect(slot.sessionStartTime, isNull);
          expect(slot.accumulatedSeconds, equals(0));
          expect(slot.displayStatus, equals(TimeSlotStatus.missed));
        },
      );

      test(
        'slot NOT eligible for cleanup: has work even if past planned end',
        () {
          final now = DateTime.now();
          final pastEnd = now.subtract(const Duration(minutes: 20));
          final pastStart = now.subtract(const Duration(hours: 1, minutes: 20));

          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: pastStart,
            plannedEndTime: pastEnd,
            googleCalendarEventId: 'cal-event-123',
            accumulatedSeconds: 600, // 10 min of work!
            sessionStartTime: pastStart,
            lastStopTime: pastEnd,
            isActive: false,
            isDiscarded: false,
          );

          // Has work - should NOT be cleaned up (completed, not missed)
          expect(slot.accumulatedSeconds, greaterThan(0));
          expect(slot.displayStatus, equals(TimeSlotStatus.completed));
        },
      );

      test(
        'slot NOT eligible for cleanup: imported from external calendar',
        () {
          final now = DateTime.now();
          final pastEnd = now.subtract(const Duration(minutes: 20));
          final pastStart = now.subtract(const Duration(hours: 1, minutes: 20));

          final slot = TimeSlot(
            id: 'slot-1',
            plannedStartTime: pastStart,
            plannedEndTime: pastEnd,
            externalCalendarEventId: 'external-event-123', // Imported
            accumulatedSeconds: 0,
            sessionStartTime: null,
            isActive: false,
            isDiscarded: false,
          );

          // Imported events should NOT be deleted by Signal
          expect(slot.isImportedFromExternal, isTrue);
          expect(slot.googleCalendarEventId, isNull);
        },
      );

      test('slot NOT eligible for cleanup: not yet past 15 min threshold', () {
        final now = DateTime.now();
        // Only 10 min past planned end (under 15 min threshold)
        final pastEnd = now.subtract(const Duration(minutes: 10));
        final pastStart = now.subtract(const Duration(hours: 1, minutes: 10));

        final slot = TimeSlot(
          id: 'slot-1',
          plannedStartTime: pastStart,
          plannedEndTime: pastEnd,
          googleCalendarEventId: 'cal-event-123',
          accumulatedSeconds: 0,
          sessionStartTime: null,
          isActive: false,
          isDiscarded: false,
        );

        // Not yet past the 15 min cleanup threshold
        final cleanupTime = slot.plannedEndTime.add(
          TimeSlot.sessionMergeThreshold,
        );
        expect(now.isBefore(cleanupTime), isTrue);
      });
    });
  });
}
