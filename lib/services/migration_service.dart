import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// Service responsible for migrating data from v1 to v2
class MigrationService {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  MigrationService(this._storageService);

  /// Check if migration is needed
  bool needsMigration() {
    // Migration needed if:
    // 1. We have legacy tasks AND
    // 2. Data version is less than 2
    return _storageService.hasLegacyTasks() &&
        _storageService.getDataVersion() < 2;
  }

  /// Perform the migration from v1 to v2
  Future<MigrationResult> migrate() async {
    if (!needsMigration()) {
      return MigrationResult(
        success: true,
        migratedTaskCount: 0,
        message: 'No migration needed',
      );
    }

    try {
      final legacyTasks = _storageService.getLegacyTasks();
      int migratedCount = 0;
      int skippedCount = 0;

      // Initialize default tags first
      await _storageService.initializeDefaultTags();

      for (final task in legacyTasks) {
        // Only migrate Signal tasks - Noise is implicit in v2
        if (task.type == TaskType.signal) {
          final signalTask = _convertLegacyTask(task);
          await _storageService.addSignalTask(signalTask);
          migratedCount++;
        } else {
          skippedCount++;
        }
      }

      // Update data version
      await _storageService.setDataVersion(2);

      // Note: We don't clear legacy tasks immediately
      // They're kept as backup until user explicitly clears app data
      // or we do a cleanup in a future version

      return MigrationResult(
        success: true,
        migratedTaskCount: migratedCount,
        skippedTaskCount: skippedCount,
        message: 'Successfully migrated $migratedCount signal tasks',
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        migratedTaskCount: 0,
        message: 'Migration failed: $e',
        error: e.toString(),
      );
    }
  }

  /// Convert a legacy Task to a SignalTask
  SignalTask _convertLegacyTask(Task legacyTask) {
    // Calculate estimated minutes from actual time spent
    // In v1, users tracked time manually, so we use that as the estimate
    final estimatedMinutes = legacyTask.timeSpentSeconds ~/ 60;

    return SignalTask(
      id: legacyTask.id,
      title: legacyTask.title,
      estimatedMinutes: estimatedMinutes > 0
          ? estimatedMinutes
          : 30, // Default 30 min if no time
      tagIds: [], // No tags in v1
      subTasks: [],
      status: _convertStatus(legacyTask),
      scheduledDate: legacyTask.date,
      timeSlots: _createTimeSlotFromLegacy(legacyTask),
      googleCalendarEventId: null,
      isComplete: legacyTask.isCompleted,
      createdAt: legacyTask.createdAt,
      rolledFromTaskId: null,
      remainingMinutesFromRollover: 0,
    );
  }

  /// Convert legacy task completion status to TaskStatus
  TaskStatus _convertStatus(Task legacyTask) {
    if (legacyTask.isCompleted) {
      return TaskStatus.completed;
    } else if (legacyTask.timeSpentSeconds > 0 || legacyTask.isTimerRunning) {
      return TaskStatus.inProgress;
    } else {
      return TaskStatus.notStarted;
    }
  }

  /// Create a time slot from legacy task's time data
  List<TimeSlot> _createTimeSlotFromLegacy(Task legacyTask) {
    // Only create a time slot if the task had time tracked
    if (legacyTask.timeSpentSeconds <= 0) {
      return [];
    }

    // Create a "completed" time slot representing the work done
    // We don't have exact start/end times, so we estimate based on creation date
    final duration = Duration(seconds: legacyTask.timeSpentSeconds);
    final estimatedEnd = legacyTask.createdAt.add(duration);

    return [
      TimeSlot(
        id: _uuid.v4(),
        plannedStartTime: legacyTask.createdAt,
        plannedEndTime: estimatedEnd,
        actualStartTime: legacyTask.createdAt,
        actualEndTime: estimatedEnd,
        isActive: false,
        autoEnd: true,
        linkedSubTaskIds: [],
        googleCalendarEventId: null,
        wasManualContinue: false,
      ),
    ];
  }
}

/// Result of a migration operation
class MigrationResult {
  final bool success;
  final int migratedTaskCount;
  final int skippedTaskCount;
  final String message;
  final String? error;

  MigrationResult({
    required this.success,
    required this.migratedTaskCount,
    this.skippedTaskCount = 0,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    return 'MigrationResult(success: $success, migrated: $migratedTaskCount, '
        'skipped: $skippedTaskCount, message: $message)';
  }
}
