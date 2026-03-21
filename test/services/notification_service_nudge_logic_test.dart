import 'package:flutter_test/flutter_test.dart';
import 'package:signal_noise/services/notification_service.dart';
import 'package:signal_noise/services/settings_service.dart';

void main() {
  group('NotificationService.shouldSendDailyTaskNudge', () {
    test('does not send nudge during quiet hours', () {
      final shouldSend = NotificationService.shouldSendDailyTaskNudge(
        isTimerActive: false,
        nudgesEnabled: true,
        now: DateTime(2026, 3, 20, 22, 0),
        quietStartHour: 21,
        quietEndHour: 8,
        tasksTodayCount: 0,
        hasCreatedTaskToday: false,
        nudgeCountToday: 0,
        maxPerDay: SettingsService.defaultTaskNudgeMaxPerDay,
        lastSentAt: null,
        frequencyMinutes: 180,
      );

      expect(shouldSend, isFalse);
    });

    test('does not send nudge when daily count limit is reached', () {
      final shouldSend = NotificationService.shouldSendDailyTaskNudge(
        isTimerActive: false,
        nudgesEnabled: true,
        now: DateTime(2026, 3, 20, 10, 0),
        quietStartHour: 21,
        quietEndHour: 8,
        tasksTodayCount: 0,
        hasCreatedTaskToday: false,
        nudgeCountToday: SettingsService.defaultTaskNudgeMaxPerDay,
        maxPerDay: SettingsService.defaultTaskNudgeMaxPerDay,
        lastSentAt: null,
        frequencyMinutes: 180,
      );

      expect(shouldSend, isFalse);
    });

    test('does not send nudge before frequency window has elapsed', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final shouldSend = NotificationService.shouldSendDailyTaskNudge(
        isTimerActive: false,
        nudgesEnabled: true,
        now: now,
        quietStartHour: 21,
        quietEndHour: 8,
        tasksTodayCount: 0,
        hasCreatedTaskToday: false,
        nudgeCountToday: 1,
        maxPerDay: SettingsService.defaultTaskNudgeMaxPerDay,
        lastSentAt: now.subtract(const Duration(minutes: 30)),
        frequencyMinutes: 60,
      );

      expect(shouldSend, isFalse);
    });

    test('sends nudge when no tasks and limits allow', () {
      final now = DateTime(2026, 3, 20, 10, 0);
      final shouldSend = NotificationService.shouldSendDailyTaskNudge(
        isTimerActive: false,
        nudgesEnabled: true,
        now: now,
        quietStartHour: 21,
        quietEndHour: 8,
        tasksTodayCount: 0,
        hasCreatedTaskToday: false,
        nudgeCountToday: 1,
        maxPerDay: SettingsService.defaultTaskNudgeMaxPerDay,
        lastSentAt: now.subtract(const Duration(minutes: 120)),
        frequencyMinutes: 60,
      );

      expect(shouldSend, isTrue);
    });
  });
}
