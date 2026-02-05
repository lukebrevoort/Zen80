import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/weekly_stats.dart';

void main() {
  group('WeeklyStats Model', () {
    late DateTime monday;

    setUp(() {
      // Monday, January 5, 2026
      monday = DateTime(2026, 1, 5);
    });

    group('Noise Calculation', () {
      test('totalNoiseMinutes equals focus minus signal', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 700,
        );

        expect(stats.totalNoiseMinutes, equals(300));
      });

      test('totalNoiseMinutes returns 0 when signal exceeds focus', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 500,
          totalSignalMinutes: 600, // Over 100%
        );

        expect(stats.totalNoiseMinutes, equals(0));
      });

      test('totalNoiseMinutes returns 0 for equal signal and focus', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 1000,
        );

        expect(stats.totalNoiseMinutes, equals(0));
      });
    });

    group('Signal/Noise Ratio', () {
      test('signalNoiseRatio calculates correctly', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 700,
        );

        expect(stats.signalNoiseRatio, equals(0.7));
        expect(stats.signalPercentage, equals(70));
      });

      test('signalNoiseRatio clamps to 1.0 when over 100%', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 500,
          totalSignalMinutes: 600,
        );

        expect(stats.signalNoiseRatio, equals(1.0));
      });

      test('signalNoiseRatio returns 0 when no focus time', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 0,
          totalSignalMinutes: 0,
        );

        expect(stats.signalNoiseRatio, equals(0));
      });

      test('goldenRatioAchieved returns true at 80%', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 800,
        );

        expect(stats.goldenRatioAchieved, isTrue);
      });

      test('goldenRatioAchieved returns true above 80%', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 850,
        );

        expect(stats.goldenRatioAchieved, isTrue);
      });

      test('goldenRatioAchieved returns false below 80%', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 1000,
          totalSignalMinutes: 790,
        );

        expect(stats.goldenRatioAchieved, isFalse);
      });
    });

    group('Tag Breakdown', () {
      test('addTimeToTag creates new entry', () {
        final stats = WeeklyStats(weekStartDate: monday);

        stats.addTimeToTag('tag-school', 120);

        expect(stats.getTimeForTag('tag-school'), equals(120));
      });

      test('addTimeToTag accumulates existing entries', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          tagBreakdown: {'tag-school': 60},
        );

        stats.addTimeToTag('tag-school', 30);

        expect(stats.getTimeForTag('tag-school'), equals(90));
      });

      test('getTimeForTag returns 0 for unknown tag', () {
        final stats = WeeklyStats(weekStartDate: monday);

        expect(stats.getTimeForTag('unknown-tag'), equals(0));
      });

      test('sortedTagBreakdown returns tags in descending order by time', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          tagBreakdown: {
            'tag-personal': 100,
            'tag-work': 300,
            'tag-school': 200,
          },
        );

        final sorted = stats.sortedTagBreakdown;

        expect(sorted[0].key, equals('tag-work'));
        expect(sorted[0].value, equals(300));
        expect(sorted[1].key, equals('tag-school'));
        expect(sorted[1].value, equals(200));
        expect(sorted[2].key, equals('tag-personal'));
        expect(sorted[2].value, equals(100));
      });
    });

    group('Tag Time Allocation - Multiple Tags Per Task', () {
      // This tests the behavior described in QNA_GUIDE.md:
      // "if a task has multiple tags (School + CS Class), does the full task duration
      // count toward both tags' totals? Yes it will count towards both."

      test('multiple tags per task - each tag gets full duration', () {
        final stats = WeeklyStats(weekStartDate: monday);

        // Simulating a task with both School and CS tags that took 120 minutes
        // Each tag should receive the full 120 minutes
        stats.addTimeToTag('tag-school', 120);
        stats.addTimeToTag('tag-cs', 120);

        expect(stats.getTimeForTag('tag-school'), equals(120));
        expect(stats.getTimeForTag('tag-cs'), equals(120));
      });

      test('total tag minutes can exceed total signal minutes', () {
        // If School has 5h and CS has 0h, then study for exam with both tags for 2h:
        // School = 7h, CS = 2h (total 9h in tags, but only 7h signal)
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalSignalMinutes: 420, // 7 hours total signal
          tagBreakdown: {
            'tag-school': 420, // 5h previous + 2h new = 7h
            'tag-cs': 120, // 0h previous + 2h new = 2h
          },
        );

        // Total in tags (540 min = 9h) can exceed total signal (420 min = 7h)
        // because tasks with multiple tags count toward each tag
        final totalTagMinutes = stats.tagBreakdown.values.fold(
          0,
          (a, b) => a + b,
        );
        expect(totalTagMinutes, equals(540)); // 9 hours
        expect(totalTagMinutes, greaterThan(stats.totalSignalMinutes));
      });
    });

    group('Week Dates', () {
      test('weekEndDate returns Sunday', () {
        final stats = WeeklyStats(weekStartDate: monday);

        expect(stats.weekEndDate, equals(DateTime(2026, 1, 11)));
      });

      test('getWeekStart returns Monday of the week', () {
        // Test with a Wednesday
        final wednesday = DateTime(2026, 1, 7);
        final weekStart = WeeklyStats.getWeekStart(wednesday);

        expect(weekStart, equals(monday));
        expect(weekStart.weekday, equals(DateTime.monday));
      });

      test('getWeekStart works on Monday', () {
        final weekStart = WeeklyStats.getWeekStart(monday);

        expect(weekStart, equals(monday));
      });

      test('getWeekStart works on Sunday', () {
        final sunday = DateTime(2026, 1, 11);
        final weekStart = WeeklyStats.getWeekStart(sunday);

        expect(weekStart, equals(monday));
      });

      test('getWeekStart handles month boundaries', () {
        // Saturday, January 3, 2026 - week starts on Monday Dec 29, 2025
        final saturday = DateTime(2026, 1, 3);
        final weekStart = WeeklyStats.getWeekStart(saturday);

        expect(weekStart, equals(DateTime(2025, 12, 29)));
      });
    });

    group('Formatted Output', () {
      test('formattedSignalTime formats hours and minutes', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalSignalMinutes: 150,
        );

        expect(stats.formattedSignalTime, equals('2h 30m'));
      });

      test('formattedNoiseTime formats correctly', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 180,
          totalSignalMinutes: 90,
        );

        expect(stats.formattedNoiseTime, equals('1h 30m'));
      });

      test('formattedFocusTime formats hours only', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalFocusMinutes: 480, // 8 hours
        );

        expect(stats.formattedFocusTime, equals('8h'));
      });

      test('formattedFocusTime formats minutes only', () {
        final stats = WeeklyStats(weekStartDate: monday, totalFocusMinutes: 45);

        expect(stats.formattedFocusTime, equals('45m'));
      });

      test('formattedDateRange for same month', () {
        final stats = WeeklyStats(weekStartDate: monday);

        expect(stats.formattedDateRange, equals('Jan 5 - 11'));
      });

      test('formattedDateRange for cross-month', () {
        // Week starting Dec 29, 2025 ends Jan 4, 2026
        final stats = WeeklyStats(weekStartDate: DateTime(2025, 12, 29));

        expect(stats.formattedDateRange, equals('Dec 29 - Jan 4'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          totalSignalMinutes: 100,
        );

        final copy = stats.copyWith(totalSignalMinutes: 200);

        expect(copy.totalSignalMinutes, equals(200));
        expect(stats.totalSignalMinutes, equals(100)); // Original unchanged
      });

      test('copies tag breakdown by value', () {
        final stats = WeeklyStats(
          weekStartDate: monday,
          tagBreakdown: {'tag-1': 100},
        );

        final copy = stats.copyWith();
        copy.addTimeToTag('tag-1', 50);

        // Original should not be affected
        expect(stats.getTimeForTag('tag-1'), equals(100));
        expect(copy.getTimeForTag('tag-1'), equals(150));
      });
    });
  });

  group('Focus Hours Calculation (from QNA_GUIDE)', () {
    // From QNA_GUIDE.md: By default, users have 16 focus hours (8 for sleep)

    test('default weekly focus minutes calculation', () {
      const focusHoursPerDay = 8;
      const focusMinutesPerDay = focusHoursPerDay * 60; // 480 min/day
      const focusMinutesPerWeek = focusMinutesPerDay * 7; // 3360 min/week

      expect(focusMinutesPerDay, equals(480));
      expect(focusMinutesPerWeek, equals(3360));
    });

    test('80/20 golden ratio with default focus', () {
      final stats = WeeklyStats(
        weekStartDate: DateTime(2026, 1, 5),
        totalFocusMinutes: 3360, // 8h * 7 days
        totalSignalMinutes: 2688, // 80% of 3360
      );

      expect(stats.signalNoiseRatio, closeTo(0.8, 0.001));
      expect(stats.goldenRatioAchieved, isTrue);
    });

    test('noise is everything not designated as signal', () {
      // From QNA_GUIDE: "Unless you have designated something as signal, it is noise"
      final stats = WeeklyStats(
        weekStartDate: DateTime(2026, 1, 5),
        totalFocusMinutes: 3360,
        totalSignalMinutes: 2000,
      );

      expect(stats.totalNoiseMinutes, equals(1360));
      expect(stats.signalNoiseRatio, lessThan(0.8));
      expect(stats.goldenRatioAchieved, isFalse);
    });
  });
}
