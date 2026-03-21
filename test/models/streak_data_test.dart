import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/models/models.dart';

void main() {
  group('StreakData', () {
    test('initial values match defaults', () {
      final streak = StreakData.initial();

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 0);
      expect(streak.lastGoalDate, isNull);
      expect(streak.pendingMissedDate, isNull);
    });

    test('copyWith updates only provided fields', () {
      final original = StreakData(
        currentStreak: 4,
        longestStreak: 9,
        pendingStreakBase: 4,
      );

      final updated = original.copyWith(currentStreak: 5);

      expect(updated.currentStreak, 5);
      expect(updated.longestStreak, 9);
      expect(updated.pendingStreakBase, 4);
    });

    test('copyWith clearPendingMissedDate clears pending date', () {
      final original = StreakData(
        pendingMissedDate: DateTime(2026, 3, 20),
        pendingStreakBase: 7,
      );

      final cleared = original.copyWith(clearPendingMissedDate: true);

      expect(cleared.pendingMissedDate, isNull);
      expect(cleared.pendingStreakBase, 7);
    });
  });
}
