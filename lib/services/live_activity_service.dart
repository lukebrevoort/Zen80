import 'dart:developer' as developer;

import 'package:live_activities/live_activities.dart';

import '../models/task.dart';

/// Service for managing iOS Live Activities (Dynamic Island / Lock Screen)
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final LiveActivities _liveActivities = LiveActivities();
  String? _currentActivityId;

  // App Group ID - must match the one configured in Xcode
  static const String appGroupId = 'group.com.signalnoise.app';

  /// Initialize the live activities plugin
  Future<void> initialize() async {
    await _liveActivities.init(appGroupId: appGroupId);
  }

  /// Check if Live Activities are supported on this device
  Future<bool> areActivitiesEnabled() async {
    return await _liveActivities.areActivitiesEnabled();
  }

  /// Start a live activity for a task timer
  Future<void> startTimerActivity({
    required Task task,
    required DateTime startedAt,
  }) async {
    // End any existing activity first
    await endTimerActivity();

    final isEnabled = await areActivitiesEnabled();
    if (!isEnabled) return;

    // Create activity data that will be passed to the native Swift widget
    final activityData = <String, dynamic>{
      'taskId': task.id,
      'taskTitle': task.title,
      'taskType': task.type == TaskType.signal ? 'signal' : 'noise',
      'startedAt': startedAt.millisecondsSinceEpoch,
      'timeSpentBefore': task.timeSpentSeconds,
    };

    try {
      // Use task.id as the activity identifier for consistent tracking
      _currentActivityId = await _liveActivities.createActivity(
        task.id,
        activityData,
        removeWhenAppIsKilled: false,
      );
    } catch (e) {
      // Live Activities may not be available on all devices
      developer.log(
        'Failed to create live activity: $e',
        name: 'LiveActivityService',
      );
    }
  }

  /// Update the live activity with current task state
  Future<void> updateTimerActivity({required Task task}) async {
    if (_currentActivityId == null) return;

    final activityData = <String, dynamic>{
      'taskId': task.id,
      'taskTitle': task.title,
      'taskType': task.type == TaskType.signal ? 'signal' : 'noise',
      'startedAt': task.timerStartedAt?.millisecondsSinceEpoch ?? 0,
      'timeSpentBefore': task.timeSpentSeconds,
    };

    try {
      await _liveActivities.updateActivity(_currentActivityId!, activityData);
    } catch (e) {
      developer.log(
        'Failed to update live activity: $e',
        name: 'LiveActivityService',
      );
    }
  }

  /// End the current live activity
  Future<void> endTimerActivity() async {
    if (_currentActivityId != null) {
      try {
        await _liveActivities.endActivity(_currentActivityId!);
      } catch (e) {
        developer.log(
          'Failed to end live activity: $e',
          name: 'LiveActivityService',
        );
      }
      _currentActivityId = null;
    }
  }

  /// End all live activities (useful for cleanup)
  Future<void> endAllActivities() async {
    try {
      await _liveActivities.endAllActivities();
      _currentActivityId = null;
    } catch (e) {
      developer.log(
        'Failed to end all live activities: $e',
        name: 'LiveActivityService',
      );
    }
  }

  /// Check if there's an active live activity
  bool get hasActiveActivity => _currentActivityId != null;

  /// Dispose resources
  void dispose() {
    _liveActivities.dispose();
  }
}
