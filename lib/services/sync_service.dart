import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_sync_operation.dart';
import '../models/signal_task.dart';
import '../models/time_slot.dart';
import '../models/sync_result.dart';
import '../models/google_calendar_event.dart';
import 'storage_service.dart';
import 'google_calendar_service.dart';

/// Service for managing offline sync queue and two-way calendar synchronization
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Storage keys for sync state
  static const _syncTokenKey = 'google_calendar_sync_token';
  static const _lastFullSyncKey = 'google_calendar_last_full_sync';
  static const _lastSyncKey = 'google_calendar_last_sync';

  final StorageService _storage = StorageService();
  final GoogleCalendarService _calendar = GoogleCalendarService();
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Completer<void>? _processingCompleter; // Replaces _isProcessing boolean
  Completer<SyncReport>? _syncCompleter; // For two-way sync
  bool _isInitialized = false;

  // Callbacks for UI updates
  void Function(String message)? onSyncError;
  void Function()? onSyncComplete;
  void Function(int pending)? onQueueUpdated;
  void Function(SyncReport report)? onSyncReport;
  void Function(List<GoogleCalendarEvent> deletedEvents)? onExternalDeletions;
  void Function(List<GoogleCalendarEvent> modifiedEvents)?
  onExternalModifications;

  /// Called when Signal tasks are modified by remote sync
  /// This allows SignalTaskProvider to refresh its cached state
  void Function()? onSignalTasksChanged;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      // Process any pending operations on startup if connected
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await processQueue();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('SyncService initialization error: $e');
      _isInitialized = true;
    }
  }

  /// Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Called when connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!results.contains(ConnectivityResult.none)) {
      // Back online - process queue
      processQueue();
    }
  }

  /// Check if currently online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Get count of pending operations
  int get pendingCount => _storage.getPendingSyncOperations().length;

  // ============ Queue Operations ============

  /// Queue a CREATE operation for a time slot
  Future<void> queueCreateEvent({
    required SignalTask task,
    required TimeSlot slot,
    String? colorHex,
  }) async {
    final operation = CalendarSyncOperation.createEvent(
      id: _uuid.v4(),
      taskId: task.id,
      timeSlotId: slot.id,
      title: task.title,
      start: slot.plannedStartTime,
      end: slot.plannedEndTime,
      colorHex: colorHex,
    );

    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);

    // Try to process immediately if online
    if (await isOnline()) {
      await processQueue();
    }
  }

  /// Queue an UPDATE operation for a time slot
  ///
  /// Uses plannedStartTime/plannedEndTime directly - callers should set these
  /// to the desired event times (e.g., actual session times) before calling.
  Future<void> queueUpdateEvent({
    required SignalTask task,
    required TimeSlot slot,
    required String googleCalendarEventId,
    String? colorHex,
  }) async {
    final operation = CalendarSyncOperation.updateEvent(
      id: _uuid.v4(),
      taskId: task.id,
      timeSlotId: slot.id,
      googleCalendarEventId: googleCalendarEventId,
      title: task.title,
      start: slot.plannedStartTime,
      end: slot.plannedEndTime,
      colorHex: colorHex,
    );

    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);

    if (await isOnline()) {
      await processQueue();
    }
  }

  /// Queue a DELETE operation
  Future<void> queueDeleteEvent({
    required String taskId,
    String? timeSlotId,
    required String googleCalendarEventId,
  }) async {
    final operation = CalendarSyncOperation.deleteEvent(
      id: _uuid.v4(),
      taskId: taskId,
      timeSlotId: timeSlotId,
      googleCalendarEventId: googleCalendarEventId,
    );

    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);

    if (await isOnline()) {
      await processQueue();
    }
  }

  // ============ Queue Processing ============

  /// Check if queue processing is currently in progress
  bool get isProcessing => _processingCompleter != null;

  /// Process all pending operations in the queue
  /// Uses Completer pattern to prevent race conditions - if processing is
  /// already in progress, callers can await the same Future
  Future<void> processQueue() async {
    // If already processing, wait for the existing operation to complete
    if (_processingCompleter != null) {
      return _processingCompleter!.future;
    }

    if (!_calendar.isConnected) return;

    _processingCompleter = Completer<void>();

    try {
      final operations = _storage.getPendingSyncOperations();

      for (final op in operations) {
        if (op.hasExceededRetries) {
          // Move to failed state - don't retry anymore
          debugPrint('Sync operation ${op.id} exceeded max retries');
          continue;
        }

        bool success = false;
        String? eventId;

        try {
          switch (op.type) {
            case SyncOperationType.create:
              eventId = await _processCreate(op);
              success = eventId != null;
              break;
            case SyncOperationType.update:
              success = await _processUpdate(op);
              break;
            case SyncOperationType.delete:
              success = await _processDelete(op);
              break;
          }
        } catch (e) {
          debugPrint('Sync operation error: $e');
          op.recordFailure(e.toString());
          await _storage.updateSyncOperation(op);
          onSyncError?.call('Sync failed: ${e.toString()}');
          continue;
        }

        if (success) {
          // Update the task with the event ID if created
          if (op.type == SyncOperationType.create && eventId != null) {
            await _updateTaskWithEventId(op.taskId, op.timeSlotId!, eventId);
          }

          // Remove from queue
          await _storage.removeSyncOperation(op.id);
          debugPrint('Sync operation ${op.id} completed successfully');
        } else {
          op.recordFailure('Operation failed');
          await _storage.updateSyncOperation(op);
        }
      }

      onQueueUpdated?.call(pendingCount);
      onSyncComplete?.call();
      _processingCompleter!.complete();
    } catch (e) {
      _processingCompleter!.completeError(e);
      rethrow;
    } finally {
      _processingCompleter = null;
    }
  }

  /// Process a CREATE operation
  Future<String?> _processCreate(CalendarSyncOperation op) async {
    // Get the task to get tag color
    final task = _storage.getSignalTask(op.taskId);
    if (task == null) {
      debugPrint('Task ${op.taskId} not found for sync');
      return null;
    }

    final slotIndex = task.timeSlots.indexWhere((s) => s.id == op.timeSlotId);
    if (slotIndex == -1) {
      debugPrint('Time slot ${op.timeSlotId} not found for sync');
      return null;
    }

    final slot = task.timeSlots[slotIndex];

    return await _calendar.createEventForTimeSlot(
      task: task,
      slot: slot,
      colorId: _hexToGoogleColorId(op.eventColorHex),
    );
  }

  /// Process an UPDATE operation
  Future<bool> _processUpdate(CalendarSyncOperation op) async {
    if (op.googleCalendarEventId == null) return false;

    return await _calendar.updateEvent(
      eventId: op.googleCalendarEventId!,
      title: op.eventTitle,
      startTime: op.eventStart,
      endTime: op.eventEnd,
      colorId: _hexToGoogleColorId(op.eventColorHex),
    );
  }

  /// Process a DELETE operation
  Future<bool> _processDelete(CalendarSyncOperation op) async {
    if (op.googleCalendarEventId == null) return false;
    return await _calendar.deleteEvent(op.googleCalendarEventId!);
  }

  /// Update the SignalTask with the Google Calendar event ID
  Future<void> _updateTaskWithEventId(
    String taskId,
    String slotId,
    String eventId,
  ) async {
    final task = _storage.getSignalTask(taskId);
    if (task == null) return;

    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;

    task.timeSlots[slotIndex] = task.timeSlots[slotIndex].copyWith(
      googleCalendarEventId: eventId,
    );

    await _storage.updateSignalTask(task);
    debugPrint('Updated task $taskId slot $slotId with event ID $eventId');
  }

  /// Public wrapper for color mapping (used by sync operations and testing)
  String? hexToGoogleColorId(String? hex) {
    return _hexToGoogleColorId(hex);
  }

  /// Convert hex color to Google Calendar color ID
  ///
  /// Maps Signal tag colors to Google Calendar event colors (1-11):
  /// 1=Lavender, 2=Sage, 3=Grape, 4=Flamingo, 5=Banana, 6=Tangerine,
  /// 7=Peacock, 8=Graphite, 9=Blueberry, 10=Basil, 11=Tomato
  String? _hexToGoogleColorId(String? hex) {
    if (hex == null) return '9'; // Default to Blueberry

    final normalized = hex.toUpperCase().replaceAll('#', '');

    // Complete mapping for all 18 Tag.colorOptions
    switch (normalized) {
      // Reds → Tomato (11)
      case 'EF4444':
        return '11';

      // Oranges → Tangerine (6)
      case 'F97316':
        return '6';

      // Yellows/Ambers → Banana (5)
      case 'F59E0B':
      case 'EAB308':
        return '5';

      // Greens/Limes → Basil (10)
      case '84CC16':
      case '22C55E':
      case '10B981':
        return '10';

      // Teals/Cyans → Peacock (7)
      case '14B8A6':
      case '06B6D4':
        return '7';

      // Blues/Sky → Blueberry (9)
      case '0EA5E9':
      case '3B82F6':
        return '9';

      // Purples/Indigos → Grape (3)
      case '6366F1':
      case '8B5CF6':
      case 'A855F7':
        return '3';

      // Pinks/Fuchsias → Flamingo (4)
      case 'D946EF':
      case 'EC4899':
      case 'F43F5E':
        return '4';

      // Gray/Stone → Graphite (8)
      case '78716C':
        return '8';

      // Legacy mappings for backward compatibility
      case '4285F4':
      case '3F51B5':
        return '9'; // Blue → Blueberry
      case '34A853':
      case '0B8043':
        return '10'; // Green → Basil
      case 'FBBC04':
      case 'F6BF26':
        return '5'; // Yellow → Banana
      case 'EA4335':
      case 'D50000':
        return '11'; // Red → Tomato
      case '9C27B0':
      case '8E24AA':
        return '3'; // Purple → Grape
      case 'FF5722':
      case 'FF8A65':
        return '6'; // Orange → Tangerine
      case '7986CB':
        return '1'; // Lavender
      case '33B679':
        return '2'; // Sage
      case 'E67C73':
        return '4'; // Flamingo
      case '039BE5':
        return '7'; // Peacock
      case '616161':
        return '8'; // Graphite

      default:
        // Fallback: try to find closest match based on RGB values
        return _findClosestGoogleColor(hex);
    }
  }

  /// Find closest Google Calendar color based on RGB proximity
  String _findClosestGoogleColor(String hex) {
    try {
      final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

      // Google Calendar event colors with their RGB values
      final googleColors = {
        '1': Color(0xFF7986CB), // Lavender
        '2': Color(0xFF33B679), // Sage
        '3': Color(0xFF9C27B0), // Grape
        '4': Color(0xFFE67C73), // Flamingo
        '5': Color(0xFFFFD54F), // Banana
        '6': Color(0xFFFF8A65), // Tangerine
        '7': Color(0xFF039BE5), // Peacock
        '8': Color(0xFF616161), // Graphite
        '9': Color(0xFF4285F4), // Blueberry
        '10': Color(0xFF0B8043), // Basil
        '11': Color(0xFFE53935), // Tomato
      };

      // Find closest color by Euclidean distance in RGB space
      String closestId = '9'; // Default to Blueberry
      double closestDistance = double.infinity;

      for (final entry in googleColors.entries) {
        final distance = sqrt(
          pow(color.r - entry.value.r, 2) +
              pow(color.g - entry.value.g, 2) +
              pow(color.b - entry.value.b, 2),
        );

        if (distance < closestDistance) {
          closestDistance = distance;
          closestId = entry.key;
        }
      }

      return closestId;
    } catch (e) {
      return '9'; // Default to Blueberry on error
    }
  }

  /// Clear all pending operations (use with caution)
  Future<void> clearQueue() async {
    await _storage.clearSyncQueue();
    onQueueUpdated?.call(0);
  }

  /// Get all failed operations (for debugging/retry UI)
  List<CalendarSyncOperation> getFailedOperations() {
    return _storage
        .getPendingSyncOperations()
        .where((op) => op.hasExceededRetries)
        .toList();
  }

  // ============ Sync Token Management ============

  /// Get the stored sync token for incremental sync
  Future<String?> getSyncToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncTokenKey);
  }

  /// Store the sync token after a successful sync
  Future<void> setSyncToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncTokenKey, token);
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Clear the sync token (forces full sync on next attempt)
  Future<void> clearSyncToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncTokenKey);
  }

  /// Get the timestamp of the last full sync
  Future<DateTime?> getLastFullSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastFullSyncKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// Store the timestamp of a full sync
  Future<void> _setLastFullSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFullSyncKey, DateTime.now().toIso8601String());
  }

  /// Get the timestamp of the last sync (full or incremental)
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastSyncKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// Check if a sync is currently in progress
  bool get isSyncing => _syncCompleter != null;

  // ============ Two-Way Sync ============

  /// Main sync entry point - orchestrates push and pull operations
  /// Call this on app launch, resume, and periodically
  Future<SyncReport> performSync({bool forceFullSync = false}) async {
    // If already syncing, wait for the existing operation to complete
    if (_syncCompleter != null) {
      return _syncCompleter!.future;
    }

    // Check prerequisites
    if (!_calendar.isConnected) {
      return SyncReport.notConnected();
    }

    if (!await isOnline()) {
      return SyncReport.offline();
    }

    _syncCompleter = Completer<SyncReport>();
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[Sync] Starting two-way sync...');

      // Phase 1: Push local changes to Google Calendar
      await processQueue();

      // Phase 2: Pull remote changes from Google Calendar
      SyncReport report;
      final syncToken = forceFullSync ? null : await getSyncToken();

      if (syncToken == null) {
        // No token - perform full sync
        debugPrint('[Sync] Performing full sync (no token or forced)');
        report = await _performFullSync();
      } else {
        // Have token - try incremental sync
        debugPrint('[Sync] Performing incremental sync');
        try {
          report = await _performIncrementalSync(syncToken);
        } on SyncTokenExpiredException {
          // Token expired - fall back to full sync
          debugPrint('[Sync] Token expired, falling back to full sync');
          await clearSyncToken();
          report = await _performFullSync();
        }
      }

      stopwatch.stop();
      final finalReport = SyncReport(
        status: report.status,
        pushedCreates: report.pushedCreates,
        pushedUpdates: report.pushedUpdates,
        pushedDeletes: report.pushedDeletes,
        pulledCreates: report.pulledCreates,
        pulledUpdates: report.pulledUpdates,
        pulledDeletes: report.pulledDeletes,
        conflictsResolved: report.conflictsResolved,
        conflictDetails: report.conflictDetails,
        wasFullSync: report.wasFullSync,
        duration: stopwatch.elapsed,
      );

      debugPrint('[Sync] Completed: $finalReport');
      onSyncReport?.call(finalReport);
      _syncCompleter!.complete(finalReport);
      return finalReport;
    } catch (e) {
      stopwatch.stop();
      final errorReport = SyncReport.error(e.toString());
      debugPrint('[Sync] Error: $e');
      onSyncError?.call(e.toString());
      _syncCompleter!.complete(errorReport);
      return errorReport;
    } finally {
      _syncCompleter = null;
    }
  }

  /// Perform a full sync - fetches all events and establishes baseline
  Future<SyncReport> _performFullSync() async {
    try {
      final result = await _calendar.performFullSync(
        // Sync events from 30 days ago to 90 days in future
        timeMin: DateTime.now().subtract(const Duration(days: 30)),
        timeMax: DateTime.now().add(const Duration(days: 90)),
      );

      // Store the sync token for future incremental syncs
      await setSyncToken(result.syncToken);
      await _setLastFullSyncTime();

      // Process the fetched events
      final processResult = await _processRemoteEvents(
        changedEvents: result.events,
        deletedEventIds: [],
        isFullSync: true,
      );

      return SyncReport(
        status: SyncStatus.success,
        pulledCreates: processResult.creates,
        pulledUpdates: processResult.updates,
        pulledDeletes: processResult.deletes,
        wasFullSync: true,
      );
    } catch (e) {
      debugPrint('[Sync] Full sync failed: $e');
      return SyncReport.error('Full sync failed: $e');
    }
  }

  /// Perform incremental sync - fetches only changes since last sync
  Future<SyncReport> _performIncrementalSync(String syncToken) async {
    final result = await _calendar.performIncrementalSync(syncToken);

    // Store the new sync token
    await setSyncToken(result.newSyncToken);

    if (!result.hasChanges) {
      debugPrint('[Sync] No changes since last sync');
      return SyncReport(status: SyncStatus.success);
    }

    // Process the changes
    final processResult = await _processRemoteEvents(
      changedEvents: result.changedEvents,
      deletedEventIds: result.deletedEventIds,
      isFullSync: false,
    );

    return SyncReport(
      status: SyncStatus.success,
      pulledCreates: processResult.creates,
      pulledUpdates: processResult.updates,
      pulledDeletes: processResult.deletes,
      conflictsResolved: processResult.conflicts,
      wasFullSync: false,
    );
  }

  /// Process events received from Google Calendar
  Future<_ProcessResult> _processRemoteEvents({
    required List<GoogleCalendarEvent> changedEvents,
    required List<String> deletedEventIds,
    required bool isFullSync,
  }) async {
    int creates = 0;
    int updates = 0;
    int deletes = 0;
    int conflicts = 0;

    // Handle deleted events
    for (final eventId in deletedEventIds) {
      final handled = await _handleDeletedEvent(eventId);
      if (handled) deletes++;
    }

    // Handle changed events
    for (final event in changedEvents) {
      // Skip events that are Signal-created (we manage those)
      if (event.isSignalTask) {
        // This is a Signal task event - check for external modifications
        final result = await _handleSignalEventModification(event);
        if (result == _ModificationResult.updated) updates++;
        if (result == _ModificationResult.conflict) conflicts++;
        continue;
      }

      // External event - check if it's linked to a Signal task
      final linkedTask = _findTaskByExternalEventId(event.id);
      if (linkedTask != null) {
        // Event is linked to a Signal task - update if modified externally
        final result = await _handleLinkedEventModification(event, linkedTask);
        if (result == _ModificationResult.updated) updates++;
        if (result == _ModificationResult.conflict) conflicts++;
      }
      // For unlinked external events, we don't need to do anything special
      // They'll be shown in the calendar view via CalendarProvider
    }

    // Notify about external deletions if any
    if (deletes > 0) {
      debugPrint('[Sync] Processed $deletes deletions from Google Calendar');
    }

    return _ProcessResult(
      creates: creates,
      updates: updates,
      deletes: deletes,
      conflicts: conflicts,
    );
  }

  /// Handle an event that was deleted in Google Calendar
  Future<bool> _handleDeletedEvent(String eventId) async {
    // Check if this event is linked to any Signal task time slot
    final allTasks = _storage.getAllSignalTasks();

    for (final task in allTasks) {
      // Check if any time slot references this event
      for (int i = 0; i < task.timeSlots.length; i++) {
        final slot = task.timeSlots[i];

        // Check googleCalendarEventId (Signal-created events)
        if (slot.googleCalendarEventId == eventId) {
          debugPrint(
            '[Sync] Event $eventId was deleted - clearing from slot ${slot.id}',
          );
          // Clear the calendar link but keep the slot
          task.timeSlots[i] = slot.copyWith(clearGoogleCalendarEventId: true);
          await _storage.updateSignalTask(task);
          onSignalTasksChanged?.call(); // Notify provider to refresh
          return true;
        }

        // Check externalCalendarEventId (imported events)
        if (slot.externalCalendarEventId == eventId) {
          debugPrint(
            '[Sync] Imported event $eventId was deleted - removing slot ${slot.id}',
          );
          // Remove the entire time slot since it was based on an external event
          task.timeSlots.removeAt(i);
          await _storage.updateSignalTask(task);
          onSignalTasksChanged?.call(); // Notify provider to refresh
          return true;
        }
      }
    }

    return false;
  }

  /// Handle modifications to a Signal-created event
  Future<_ModificationResult> _handleSignalEventModification(
    GoogleCalendarEvent event,
  ) async {
    // Find the task/slot that owns this event
    final allTasks = _storage.getAllSignalTasks();

    for (final task in allTasks) {
      for (int i = 0; i < task.timeSlots.length; i++) {
        final slot = task.timeSlots[i];
        if (slot.googleCalendarEventId == event.id) {
          // Found the slot - check if times were modified externally
          final localStart = slot.plannedStartTime;
          final localEnd = slot.plannedEndTime;
          final remoteStart = event.startTime;
          final remoteEnd = event.endTime;

          // Check for time differences (allowing 1 minute tolerance)
          final startDiff = localStart.difference(remoteStart).inMinutes.abs();
          final endDiff = localEnd.difference(remoteEnd).inMinutes.abs();

          if (startDiff > 1 || endDiff > 1) {
            debugPrint(
              '[Sync] External modification detected for event ${event.id}',
            );
            debugPrint(
              '[Sync] Updating local: $localStart-$localEnd -> $remoteStart-$remoteEnd',
            );
            // External modification - update local slot
            task.timeSlots[i] = slot.copyWith(
              plannedStartTime: remoteStart,
              plannedEndTime: remoteEnd,
            );
            await _storage.updateSignalTask(task);
            onSignalTasksChanged?.call(); // Notify provider to refresh
            return _ModificationResult.updated;
          }

          return _ModificationResult.noChange;
        }
      }
    }

    return _ModificationResult.noChange;
  }

  /// Handle modifications to an event linked to a Signal task
  Future<_ModificationResult> _handleLinkedEventModification(
    GoogleCalendarEvent event,
    SignalTask task,
  ) async {
    // Find the slot linked to this event
    for (int i = 0; i < task.timeSlots.length; i++) {
      final slot = task.timeSlots[i];
      if (slot.externalCalendarEventId == event.id) {
        // Check for time changes
        final localStart = slot.plannedStartTime;
        final localEnd = slot.plannedEndTime;
        final remoteStart = event.startTime;
        final remoteEnd = event.endTime;

        final startDiff = localStart.difference(remoteStart).inMinutes.abs();
        final endDiff = localEnd.difference(remoteEnd).inMinutes.abs();

        if (startDiff > 1 || endDiff > 1) {
          debugPrint('[Sync] Linked event ${event.id} was modified externally');
          debugPrint(
            '[Sync] Updating local: $localStart-$localEnd -> $remoteStart-$remoteEnd',
          );
          task.timeSlots[i] = slot.copyWith(
            plannedStartTime: remoteStart,
            plannedEndTime: remoteEnd,
          );
          await _storage.updateSignalTask(task);
          onSignalTasksChanged?.call(); // Notify provider to refresh
          return _ModificationResult.updated;
        }

        return _ModificationResult.noChange;
      }
    }

    return _ModificationResult.noChange;
  }

  /// Find a Signal task that has a time slot linked to the given external event ID
  SignalTask? _findTaskByExternalEventId(String eventId) {
    final allTasks = _storage.getAllSignalTasks();
    for (final task in allTasks) {
      for (final slot in task.timeSlots) {
        if (slot.externalCalendarEventId == eventId ||
            slot.googleCalendarEventId == eventId) {
          return task;
        }
      }
    }
    return null;
  }
}

// ============ Helper Classes ============

/// Result of processing remote events
class _ProcessResult {
  final int creates;
  final int updates;
  final int deletes;
  final int conflicts;

  _ProcessResult({
    this.creates = 0,
    this.updates = 0,
    this.deletes = 0,
    this.conflicts = 0,
  });
}

/// Result of handling a modification
enum _ModificationResult { noChange, updated, conflict }
