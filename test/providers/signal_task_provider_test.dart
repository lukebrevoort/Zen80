import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/time_slot.dart';
import 'package:signal_noise/providers/signal_task_provider.dart';

void main() {
  group('SignalTaskProvider Constants', () {
    test('midnight cutoff is set to 23:59', () {
      expect(SignalTaskProvider.midnightCutoffHour, equals(23));
      expect(SignalTaskProvider.midnightCutoffMinute, equals(59));
    });

    test('session merge threshold is 15 minutes', () {
      expect(
        SignalTaskProvider.sessionMergeThreshold,
        equals(const Duration(minutes: 15)),
      );
    });

    test('short task commitment threshold is 5 minutes', () {
      expect(
        SignalTaskProvider.shortTaskCommitmentThreshold,
        equals(const Duration(minutes: 5)),
      );
    });

    test('long task commitment threshold is 10 minutes', () {
      expect(
        SignalTaskProvider.longTaskCommitmentThreshold,
        equals(const Duration(minutes: 10)),
      );
    });
  });

  group('Midnight Cutoff Logic', () {
    test('midnight cutoff for anchor is 23:59 on same day', () {
      final cutoff = SignalTaskProvider.midnightCutoffForAnchor(
        DateTime(2026, 1, 5, 9, 30),
      );

      expect(cutoff, equals(DateTime(2026, 1, 5, 23, 59)));
    });

    test('slot cutoff uses session start day when available', () {
      final slot = TimeSlot(
        id: 'slot-1',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        actualStartTime: DateTime(2026, 1, 5, 10, 5),
        sessionStartTime: DateTime(2026, 1, 5, 10, 0),
        isActive: true,
      );

      expect(
        SignalTaskProvider.midnightCutoffForSlot(slot),
        equals(DateTime(2026, 1, 5, 23, 59)),
      );
    });

    test('slot cutoff falls back to actualStartTime when needed', () {
      final slot = TimeSlot(
        id: 'slot-2',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        actualStartTime: DateTime(2026, 1, 5, 10, 5),
        isActive: true,
      );

      expect(
        SignalTaskProvider.midnightCutoffForSlot(slot),
        equals(DateTime(2026, 1, 5, 23, 59)),
      );
    });

    test('slot cutoff falls back to plannedStartTime as last resort', () {
      final slot = TimeSlot(
        id: 'slot-3',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        isActive: true,
      );

      expect(
        SignalTaskProvider.midnightCutoffForSlot(slot),
        equals(DateTime(2026, 1, 5, 23, 59)),
      );
    });

    test(
      'next-morning reopen still maps to prior-day cutoff (OS kill/restart)',
      () {
        final slot = TimeSlot(
          id: 'slot-4',
          plannedStartTime: DateTime(2026, 1, 5, 20, 0),
          plannedEndTime: DateTime(2026, 1, 5, 21, 0),
          sessionStartTime: DateTime(2026, 1, 5, 20, 0),
          isActive: true,
        );

        final cutoff = SignalTaskProvider.midnightCutoffForSlot(slot);
        final appResumeAfterRestart = DateTime(2026, 1, 6, 7, 30);

        expect(cutoff, equals(DateTime(2026, 1, 5, 23, 59)));
        expect(appResumeAfterRestart.isAfter(cutoff), isTrue);
      },
    );

    test('manual stops before cutoff remain valid', () {
      final slot = TimeSlot(
        id: 'slot-5',
        plannedStartTime: DateTime(2026, 1, 5, 20, 0),
        plannedEndTime: DateTime(2026, 1, 5, 21, 0),
        sessionStartTime: DateTime(2026, 1, 5, 20, 0),
        isActive: true,
      );

      final cutoff = SignalTaskProvider.midnightCutoffForSlot(slot);
      final manualStopTime = DateTime(2026, 1, 5, 21, 30);

      expect(manualStopTime.isBefore(cutoff), isTrue);
    });

    test('auto-end slot prefers planned end over midnight cutoff', () {
      final slot = TimeSlot(
        id: 'slot-auto-end-planned',
        plannedStartTime: DateTime(2026, 1, 5, 18, 0),
        plannedEndTime: DateTime(2026, 1, 5, 20, 0),
        sessionStartTime: DateTime(2026, 1, 5, 18, 0),
        autoEnd: true,
        isActive: true,
      );

      expect(SignalTaskProvider.shouldStopAtPlannedEnd(slot), isTrue);
      expect(
        SignalTaskProvider.effectiveAutoStopTimeForSlot(slot),
        equals(DateTime(2026, 1, 5, 20, 0)),
      );
    });

    test('manual-continue slot falls back to midnight cutoff', () {
      final slot = TimeSlot(
        id: 'slot-manual-continue',
        plannedStartTime: DateTime(2026, 1, 5, 18, 0),
        plannedEndTime: DateTime(2026, 1, 5, 20, 0),
        sessionStartTime: DateTime(2026, 1, 5, 18, 0),
        autoEnd: true,
        wasManualContinue: true,
        isActive: true,
      );

      expect(SignalTaskProvider.shouldStopAtPlannedEnd(slot), isFalse);
      expect(
        SignalTaskProvider.effectiveAutoStopTimeForSlot(slot),
        equals(DateTime(2026, 1, 5, 23, 59)),
      );
    });

    test('planned end after midnight cutoff still stops at midnight', () {
      final slot = TimeSlot(
        id: 'slot-after-midnight',
        plannedStartTime: DateTime(2026, 1, 5, 23, 0),
        plannedEndTime: DateTime(2026, 1, 6, 1, 0),
        sessionStartTime: DateTime(2026, 1, 5, 23, 0),
        autoEnd: true,
        isActive: true,
      );

      expect(SignalTaskProvider.shouldStopAtPlannedEnd(slot), isFalse);
      expect(
        SignalTaskProvider.effectiveAutoStopTimeForSlot(slot),
        equals(DateTime(2026, 1, 5, 23, 59)),
      );
    });
  });

  group('Task Limits', () {
    test('max signal tasks is 5', () {
      expect(SignalTaskProvider.maxSignalTasks, equals(5));
    });

    test('min signal tasks is 3', () {
      expect(SignalTaskProvider.minSignalTasks, equals(3));
    });
  });

  group('Auto-End Callback Gate', () {
    test('emits callback for ended non-discarded slot', () {
      final slot = TimeSlot(
        id: 'ended-slot',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        actualStartTime: DateTime(2026, 1, 5, 10, 0),
        actualEndTime: DateTime(2026, 1, 5, 11, 0),
        isActive: false,
        isDiscarded: false,
      );

      expect(SignalTaskProvider.shouldEmitAutoEndCallback(slot), isTrue);
    });

    test('does not emit callback for discarded slot', () {
      final slot = TimeSlot(
        id: 'discarded-slot',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        isActive: false,
        isDiscarded: true,
      );

      expect(SignalTaskProvider.shouldEmitAutoEndCallback(slot), isFalse);
    });

    test('does not emit callback for reset pre-scheduled slot', () {
      final slot = TimeSlot(
        id: 'reset-slot',
        plannedStartTime: DateTime(2026, 1, 5, 10, 0),
        plannedEndTime: DateTime(2026, 1, 5, 11, 0),
        googleCalendarEventId: 'gcal-1',
        isActive: false,
        isDiscarded: false,
      );

      expect(SignalTaskProvider.shouldEmitAutoEndCallback(slot), isFalse);
    });
  });
}
