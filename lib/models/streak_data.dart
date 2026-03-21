import 'package:hive/hive.dart';

part 'streak_data.g.dart';

@HiveType(typeId: 22)
class StreakData extends HiveObject {
  @HiveField(0)
  int currentStreak;

  @HiveField(1)
  int longestStreak;

  @HiveField(2)
  DateTime? lastGoalDate;

  @HiveField(3)
  DateTime? lastProcessedDate;

  @HiveField(5)
  DateTime? pendingMissedDate;

  @HiveField(6)
  int pendingStreakBase;

  StreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastGoalDate,
    this.lastProcessedDate,
    this.pendingMissedDate,
    this.pendingStreakBase = 0,
  });

  factory StreakData.initial() => StreakData();

  StreakData copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastGoalDate,
    DateTime? lastProcessedDate,
    DateTime? pendingMissedDate,
    int? pendingStreakBase,
    bool clearLastGoalDate = false,
    bool clearLastProcessedDate = false,
    bool clearPendingMissedDate = false,
  }) {
    return StreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastGoalDate: clearLastGoalDate
          ? null
          : (lastGoalDate ?? this.lastGoalDate),
      lastProcessedDate: clearLastProcessedDate
          ? null
          : (lastProcessedDate ?? this.lastProcessedDate),
      pendingMissedDate: clearPendingMissedDate
          ? null
          : (pendingMissedDate ?? this.pendingMissedDate),
      pendingStreakBase: pendingStreakBase ?? this.pendingStreakBase,
    );
  }
}
