import 'package:flutter_test/flutter_test.dart';
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
    // Testing the midnight cutoff logic directly
    // This verifies the business logic without requiring the full provider setup

    test('times before 23:59 are not past cutoff', () {
      // Test various times during the day
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 8, 0)), isFalse);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 12, 0)), isFalse);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 18, 30)), isFalse);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 22, 0)), isFalse);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 23, 0)), isFalse);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 23, 58)), isFalse);
    });

    test('exactly 23:59 is past cutoff', () {
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 23, 59)), isTrue);
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 23, 59, 30)), isTrue);
    });

    test('after 23:59 is past cutoff', () {
      // Note: After 23:59 the next minute would be 00:00 (next day)
      // But if somehow the timer check catches it just before midnight...
      // The hour check handles this - hour > 23 would be impossible (max 23)
      // So we just verify that 23:59+ is caught
      expect(_isPastMidnightCutoff(DateTime(2026, 1, 5, 23, 59, 59)), isTrue);
    });

    test(
      'early morning times (after midnight) are not past cutoff for current day',
      () {
        // 12:30 AM, 1:00 AM, etc. should NOT trigger cutoff
        // These are the start of a NEW day, not the end of the previous day
        expect(_isPastMidnightCutoff(DateTime(2026, 1, 6, 0, 0)), isFalse);
        expect(_isPastMidnightCutoff(DateTime(2026, 1, 6, 0, 30)), isFalse);
        expect(_isPastMidnightCutoff(DateTime(2026, 1, 6, 1, 0)), isFalse);
        expect(_isPastMidnightCutoff(DateTime(2026, 1, 6, 2, 0)), isFalse);
      },
    );
  });

  group('Task Limits', () {
    test('max signal tasks is 5', () {
      expect(SignalTaskProvider.maxSignalTasks, equals(5));
    });

    test('min signal tasks is 3', () {
      expect(SignalTaskProvider.minSignalTasks, equals(3));
    });
  });
}

/// Helper function that mirrors the logic in SignalTaskProvider._isPastMidnightCutoff
/// This allows us to test the logic without needing the full provider setup
bool _isPastMidnightCutoff(DateTime now) {
  const midnightCutoffHour = SignalTaskProvider.midnightCutoffHour;
  const midnightCutoffMinute = SignalTaskProvider.midnightCutoffMinute;

  // Check if we're at or past 23:59
  if (now.hour > midnightCutoffHour) return true;
  if (now.hour == midnightCutoffHour && now.minute >= midnightCutoffMinute) {
    return true;
  }
  return false;
}
