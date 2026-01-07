import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'sync_service.dart';
import 'google_calendar_service.dart';

/// Background sync frequency options (in minutes)
enum SyncFrequency {
  minutes15(15, '15 minutes'),
  minutes30(30, '30 minutes'),
  hour1(60, '1 hour'),
  manualOnly(0, 'Manual only');

  final int minutes;
  final String displayName;
  const SyncFrequency(this.minutes, this.displayName);

  /// Get frequency from minutes value
  static SyncFrequency fromMinutes(int minutes) {
    return SyncFrequency.values.firstWhere(
      (f) => f.minutes == minutes,
      orElse: () => SyncFrequency.minutes15,
    );
  }
}

/// Task name constants for workmanager
class BackgroundTasks {
  static const String calendarSync =
      'com.lukebrevoort.signalNoise.backgroundSync';
}

/// Top-level callback dispatcher for workmanager
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundSync] Executing task: $taskName');

    try {
      // Initialize the Google Calendar service (this restores auth silently)
      final calendarService = GoogleCalendarService();
      await calendarService.initialize();

      // Check if we're actually connected
      if (!calendarService.isConnected) {
        debugPrint(
          '[BackgroundSync] Not connected to Google Calendar, skipping sync',
        );
        return Future.value(true); // Task completed (even though we skipped)
      }

      // Initialize sync service and perform sync
      final syncService = SyncService();
      await syncService.initialize();

      final report = await syncService.performSync();

      debugPrint('[BackgroundSync] Sync completed: ${report.status}');

      // If there were changes pulled from remote, log them
      // Note: We can't show notifications easily from background on iOS
      // The user will see updates when they open the app
      final totalPulled =
          report.pulledCreates + report.pulledUpdates + report.pulledDeletes;

      if (totalPulled > 0) {
        debugPrint(
          '[BackgroundSync] Synced $totalPulled changes from Google Calendar',
        );
      }

      // Update last background sync time
      await BackgroundSyncService._updateLastBackgroundSyncTime();

      return Future.value(true);
    } catch (e) {
      debugPrint('[BackgroundSync] Error during sync: $e');
      return Future.value(false); // Task failed, may retry
    }
  });
}

/// Service for managing background calendar synchronization
class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  // Storage keys
  static const String _syncFrequencyKey = 'background_sync_frequency_minutes';
  static const String _lastBackgroundSyncKey = 'last_background_sync_time';

  bool _isInitialized = false;

  /// Initialize the background sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize workmanager with the callback dispatcher
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Schedule the periodic sync task based on user preference
      await _schedulePeriodicSync();

      _isInitialized = true;
      debugPrint('[BackgroundSync] Service initialized');
    } catch (e) {
      debugPrint('[BackgroundSync] Initialization error: $e');
      _isInitialized =
          true; // Mark as initialized even on error to prevent retry loops
    }
  }

  /// Schedule the periodic sync task
  Future<void> _schedulePeriodicSync() async {
    final frequency = await getSyncFrequency();

    try {
      if (frequency == SyncFrequency.manualOnly) {
        // Cancel any existing periodic task
        await Workmanager().cancelByUniqueName(BackgroundTasks.calendarSync);
        debugPrint('[BackgroundSync] Background sync disabled (manual only)');
        return;
      }

      // Cancel existing task before registering new one
      await Workmanager().cancelByUniqueName(BackgroundTasks.calendarSync);

      // Register periodic task
      // Note: iOS has a minimum interval of 15 minutes for background tasks
      // and the actual execution time is determined by the system.
      //
      // On some targets (notably iOS Simulator, or if the plugin isn't wired up),
      // Workmanager can throw PlatformException("Unhandled method registerPeriodicTask").
      // In that case we fail gracefully:
      // - keep the user's preference saved
      // - do not crash
      // - continue to allow manual sync
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.calendarSync,
        BackgroundTasks.calendarSync,
        frequency: Duration(minutes: frequency.minutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      debugPrint(
        '[BackgroundSync] Scheduled periodic sync every ${frequency.minutes} minutes',
      );
    } catch (e) {
      debugPrint('[BackgroundSync] Failed to schedule periodic sync: $e');
      // Swallow the exception so UI settings changes don't crash on unsupported targets.
      // The user can still sync manually from the app.
    }
  }

  /// Get the current sync frequency setting
  Future<SyncFrequency> getSyncFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes =
        prefs.getInt(_syncFrequencyKey) ?? SyncFrequency.minutes15.minutes;
    return SyncFrequency.fromMinutes(minutes);
  }

  /// Set the sync frequency
  Future<void> setSyncFrequency(SyncFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncFrequencyKey, frequency.minutes);

    // Reschedule the periodic task with new frequency
    await _schedulePeriodicSync();

    debugPrint(
      '[BackgroundSync] Sync frequency set to: ${frequency.displayName}',
    );
  }

  /// Check if background sync is enabled
  Future<bool> isEnabled() async {
    final frequency = await getSyncFrequency();
    return frequency != SyncFrequency.manualOnly;
  }

  /// Enable or disable background sync
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      // Enable with default frequency
      await setSyncFrequency(SyncFrequency.minutes15);
    } else {
      await setSyncFrequency(SyncFrequency.manualOnly);
    }
  }

  /// Get the last background sync time
  Future<DateTime?> getLastBackgroundSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastBackgroundSyncKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// Update the last background sync time (called from background task)
  static Future<void> _updateLastBackgroundSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackgroundSyncKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Trigger an immediate sync (from the UI, not background)
  Future<void> triggerImmediateSync() async {
    // This is just a convenience method that calls SyncService directly
    // The actual sync is performed by SyncService
    final syncService = SyncService();
    await syncService.performSync();
  }

  /// Cancel all background tasks
  Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('[BackgroundSync] All background tasks cancelled');
  }

  /// Dispose the service
  void dispose() {
    // Nothing to dispose for now
  }
}
