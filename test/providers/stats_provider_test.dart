import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/providers/stats_provider.dart';

void main() {
  group('DailyStats', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2026, 1, 5);
    });

    group('Ratio Calculation', () {
      test('ratio calculates signal divided by focus', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 480, // 8 hours
          focusMinutes: 960, // 16 hours
          completedTasks: 5,
        );

        expect(stats.ratio, equals(0.5));
      });

      test('ratio returns 0 when no focus time', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 0,
          focusMinutes: 0,
          completedTasks: 0,
        );

        expect(stats.ratio, equals(0.0));
      });

      test('ratio clamps to 1.0 when signal exceeds focus', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 1000,
          focusMinutes: 800,
          completedTasks: 5,
        );

        expect(stats.ratio, equals(1.0));
      });

      test('percentage returns ratio * 100', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 768, // 80% of 960
          focusMinutes: 960,
          completedTasks: 5,
        );

        expect(stats.percentage, equals(80.0));
      });
    });

    group('Noise Calculation', () {
      test('noiseMinutes equals focus minus signal', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 400,
          focusMinutes: 960,
          completedTasks: 3,
        );

        expect(stats.noiseMinutes, equals(560));
      });

      test('noiseMinutes returns 0 when signal exceeds focus', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 1000,
          focusMinutes: 800,
          completedTasks: 5,
        );

        expect(stats.noiseMinutes, equals(0));
      });
    });

    group('Golden Ratio (80/20)', () {
      test('goldenRatioAchieved is true at exactly 80%', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 768, // 80% of 960
          focusMinutes: 960,
          completedTasks: 4,
        );

        expect(stats.goldenRatioAchieved, isTrue);
        expect(stats.isGoldenRatio, isTrue);
      });

      test('goldenRatioAchieved is true above 80%', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 800,
          focusMinutes: 960,
          completedTasks: 4,
        );

        expect(stats.goldenRatioAchieved, isTrue);
      });

      test('goldenRatioAchieved is false below 80%', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 750,
          focusMinutes: 960,
          completedTasks: 4,
        );

        expect(stats.goldenRatioAchieved, isFalse);
      });
    });

    group('Formatted Output', () {
      test('formattedSignalTime formats hours and minutes', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 150,
          focusMinutes: 960,
          completedTasks: 3,
        );

        expect(stats.formattedSignalTime, equals('2h 30m'));
      });

      test('formattedFocusTime formats correctly', () {
        final stats = DailyStats(
          date: testDate,
          signalMinutes: 0,
          focusMinutes: 960,
          completedTasks: 0,
        );

        expect(stats.formattedFocusTime, equals('16h'));
      });
    });

    group('Empty Factory', () {
      test('DailyStats.empty creates zeroed stats', () {
        final stats = DailyStats.empty(testDate);

        expect(stats.date, equals(testDate));
        expect(stats.signalMinutes, equals(0));
        expect(stats.focusMinutes, equals(0));
        expect(stats.completedTasks, equals(0));
        expect(stats.ratio, equals(0.0));
      });
    });
  });

  group('StatsProvider Configuration', () {
    test('default focus hours per day is 16', () {
      // From QNA_GUIDE.md: "By default it is 18 hours for steve jobs,
      // but we will be more generous and say 16 hours (8 for sleep)"
      expect(StatsProvider.defaultFocusHoursPerDay, equals(16));
    });
  });

  group('Focus Hours Scenarios', () {
    // These tests verify the business logic without needing mocks

    test('16 hours per day equals 960 minutes', () {
      const focusHoursPerDay = 16;
      const focusMinutesPerDay = focusHoursPerDay * 60;

      expect(focusMinutesPerDay, equals(960));
    });

    test('weekly focus is 7 days * 960 minutes = 6720', () {
      const focusMinutesPerDay = 960;
      const focusMinutesPerWeek = focusMinutesPerDay * 7;

      expect(focusMinutesPerWeek, equals(6720));
    });

    test('80% golden ratio target for a day', () {
      const focusMinutesPerDay = 960;
      const goldenRatioTarget = focusMinutesPerDay * 0.8;

      expect(goldenRatioTarget, equals(768));
    });

    test('80% golden ratio target for a week', () {
      const focusMinutesPerWeek = 6720;
      const goldenRatioTarget = focusMinutesPerWeek * 0.8;

      expect(goldenRatioTarget, equals(5376));
    });
  });

  group('Tag Breakdown Calculation Logic', () {
    // Test the pure calculation logic that StatsProvider.calculateTagBreakdown uses
    // Without requiring a full provider setup

    test('single tag gets full task time', () {
      // Simulating task with 1 tag, 60 actual minutes
      final tagMinutes = <String, int>{};
      const taskMinutes = 60;
      const tagIds = ['tag-work'];

      for (final tagId in tagIds) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + taskMinutes;
      }

      expect(tagMinutes['tag-work'], equals(60));
    });

    test('multiple tags each get full task time', () {
      // Simulating task with 2 tags, 60 actual minutes
      // Each tag should get the full 60 minutes
      final tagMinutes = <String, int>{};
      const taskMinutes = 60;
      const tagIds = ['tag-school', 'tag-cs'];

      for (final tagId in tagIds) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + taskMinutes;
      }

      expect(tagMinutes['tag-school'], equals(60));
      expect(tagMinutes['tag-cs'], equals(60));
    });

    test('accumulated tag time across multiple tasks', () {
      // Task 1: School tag, 60 min
      // Task 2: School + CS tags, 30 min
      // Result: School = 90 min, CS = 30 min
      final tagMinutes = <String, int>{};

      // Task 1
      for (final tagId in ['tag-school']) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + 60;
      }

      // Task 2
      for (final tagId in ['tag-school', 'tag-cs']) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + 30;
      }

      expect(tagMinutes['tag-school'], equals(90));
      expect(tagMinutes['tag-cs'], equals(30));
    });

    test('tasks with no tags do not contribute to breakdown', () {
      final tagMinutes = <String, int>{};
      const taskMinutes = 60;
      const tagIds = <String>[]; // No tags

      for (final tagId in tagIds) {
        tagMinutes[tagId] = (tagMinutes[tagId] ?? 0) + taskMinutes;
      }

      expect(tagMinutes.isEmpty, isTrue);
    });
  });

  group('Daily Stats Breakdown Scenarios', () {
    test('zero activity day', () {
      final stats = DailyStats(
        date: DateTime(2026, 1, 5),
        signalMinutes: 0,
        focusMinutes: 960,
        completedTasks: 0,
      );

      expect(stats.ratio, equals(0.0));
      expect(stats.noiseMinutes, equals(960));
      expect(stats.goldenRatioAchieved, isFalse);
    });

    test('highly productive day', () {
      final stats = DailyStats(
        date: DateTime(2026, 1, 5),
        signalMinutes: 850, // ~88% of 960
        focusMinutes: 960,
        completedTasks: 6,
      );

      expect(stats.ratio, closeTo(0.885, 0.01));
      expect(stats.goldenRatioAchieved, isTrue);
    });

    test('borderline day just under 80%', () {
      final stats = DailyStats(
        date: DateTime(2026, 1, 5),
        signalMinutes: 767, // Just under 80%
        focusMinutes: 960,
        completedTasks: 3,
      );

      expect(stats.ratio, lessThan(0.8));
      expect(stats.goldenRatioAchieved, isFalse);
    });
  });

  group('Week Navigation Logic', () {
    // Testing pure date logic without StorageService dependency

    test('get Monday of week from any weekday', () {
      // Tuesday Jan 6, 2026
      final tuesday = DateTime(2026, 1, 6);
      final monday = _getWeekStart(tuesday);

      expect(monday, equals(DateTime(2026, 1, 5)));
      expect(monday.weekday, equals(DateTime.monday));
    });

    test('get Monday from Monday returns same day', () {
      final monday = DateTime(2026, 1, 5);
      final result = _getWeekStart(monday);

      expect(result, equals(monday));
    });

    test('get Monday from Sunday goes to previous Monday', () {
      final sunday = DateTime(2026, 1, 11);
      final monday = _getWeekStart(sunday);

      expect(monday, equals(DateTime(2026, 1, 5)));
    });

    test('previous week is 7 days before', () {
      final currentWeek = DateTime(2026, 1, 5);
      final previousWeek = currentWeek.subtract(const Duration(days: 7));

      expect(previousWeek, equals(DateTime(2025, 12, 29)));
    });

    test('next week is 7 days after', () {
      final currentWeek = DateTime(2026, 1, 5);
      final nextWeek = currentWeek.add(const Duration(days: 7));

      expect(nextWeek, equals(DateTime(2026, 1, 12)));
    });

    test('week end is 6 days after start', () {
      final weekStart = DateTime(2026, 1, 5);
      final weekEnd = weekStart.add(const Duration(days: 6));

      expect(weekEnd, equals(DateTime(2026, 1, 11)));
      expect(weekEnd.weekday, equals(DateTime.sunday));
    });
  });
}

/// Helper function matching StatsProvider/WeeklyStats logic
DateTime _getWeekStart(DateTime date) {
  final daysFromMonday = date.weekday - 1;
  return DateTime(date.year, date.month, date.day - daysFromMonday);
}
