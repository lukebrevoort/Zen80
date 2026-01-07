import 'task.dart';

/// Summary of a single day's tasks and time distribution
class DailySummary {
  final DateTime date;
  final List<Task> tasks;

  DailySummary({required this.date, required this.tasks});

  /// Get only signal tasks
  List<Task> get signalTasks =>
      tasks.where((t) => t.type == TaskType.signal).toList();

  /// Get only noise tasks
  List<Task> get noiseTasks =>
      tasks.where((t) => t.type == TaskType.noise).toList();

  /// Total time spent on signal tasks (including active timers)
  Duration get totalSignalTime {
    return signalTasks.fold(
      Duration.zero,
      (total, task) => total + task.totalTimeIncludingTimer,
    );
  }

  /// Total time spent on noise tasks (including active timers)
  Duration get totalNoiseTime {
    return noiseTasks.fold(
      Duration.zero,
      (total, task) => total + task.totalTimeIncludingTimer,
    );
  }

  /// Total time spent on all tasks
  Duration get totalTime => totalSignalTime + totalNoiseTime;

  /// Percentage of time spent on signal (0.0 to 1.0)
  double get signalPercentage {
    if (totalTime.inSeconds == 0) return 0.0;
    return totalSignalTime.inSeconds / totalTime.inSeconds;
  }

  /// Percentage of time spent on noise (0.0 to 1.0)
  double get noisePercentage {
    if (totalTime.inSeconds == 0) return 0.0;
    return totalNoiseTime.inSeconds / totalTime.inSeconds;
  }

  /// Whether the golden ratio (80% signal) has been achieved
  bool get goldenRatioAchieved => signalPercentage >= 0.8;

  /// How close to the golden ratio (0.0 to 1.0, where 1.0 = achieved)
  double get ratioProgress {
    if (signalPercentage >= 0.8) return 1.0;
    return signalPercentage / 0.8;
  }

  /// Format total time as readable string
  String get formattedTotalTime {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '0m';
    }
  }
}
