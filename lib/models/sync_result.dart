import 'google_calendar_event.dart';

/// Result of a full sync operation
/// Contains all events from the calendar and the syncToken for future incremental syncs
class FullSyncResult {
  /// All events fetched from the calendar
  final List<GoogleCalendarEvent> events;

  /// Token to use for future incremental syncs
  final String syncToken;

  /// When the sync was performed
  final DateTime syncedAt;

  /// Total number of events fetched
  int get eventCount => events.length;

  FullSyncResult({
    required this.events,
    required this.syncToken,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();

  @override
  String toString() =>
      'FullSyncResult(events: $eventCount, syncedAt: $syncedAt)';
}

/// Result of an incremental sync operation
/// Contains only events that changed since the last sync
class IncrementalSyncResult {
  /// Events that were created or modified since last sync
  final List<GoogleCalendarEvent> changedEvents;

  /// IDs of events that were deleted since last sync
  final List<String> deletedEventIds;

  /// New token to use for the next incremental sync
  final String newSyncToken;

  /// When the sync was performed
  final DateTime syncedAt;

  /// Whether there were any changes
  bool get hasChanges => changedEvents.isNotEmpty || deletedEventIds.isNotEmpty;

  /// Total number of changes (created + modified + deleted)
  int get totalChanges => changedEvents.length + deletedEventIds.length;

  IncrementalSyncResult({
    required this.changedEvents,
    required this.deletedEventIds,
    required this.newSyncToken,
    DateTime? syncedAt,
  }) : syncedAt = syncedAt ?? DateTime.now();

  @override
  String toString() =>
      'IncrementalSyncResult(changed: ${changedEvents.length}, deleted: ${deletedEventIds.length})';
}

/// Exception thrown when the syncToken has expired or become invalid
/// Google Calendar returns HTTP 410 Gone in this case
/// The solution is to perform a full sync to get a new token
class SyncTokenExpiredException implements Exception {
  final String message;

  SyncTokenExpiredException([this.message = 'Sync token expired or invalid']);

  @override
  String toString() => 'SyncTokenExpiredException: $message';
}

/// Overall sync status
enum SyncStatus {
  /// Sync completed successfully
  success,

  /// Not connected to Google Calendar
  notConnected,

  /// Device is offline
  offline,

  /// Sync failed due to an error
  error,

  /// Sync is currently in progress
  inProgress,

  /// Sync was skipped (e.g., too soon since last sync)
  skipped,
}

/// Report of a sync operation
/// Provides detailed information about what happened during sync
class SyncReport {
  final SyncStatus status;
  final DateTime timestamp;
  final String? errorMessage;

  // Push statistics (local → Google)
  final int pushedCreates;
  final int pushedUpdates;
  final int pushedDeletes;

  // Pull statistics (Google → local)
  final int pulledCreates;
  final int pulledUpdates;
  final int pulledDeletes;

  // Conflict resolution
  final int conflictsResolved;
  final List<String> conflictDetails;

  /// Whether this was a full sync or incremental
  final bool wasFullSync;

  /// Duration of the sync operation
  final Duration? duration;

  SyncReport({
    required this.status,
    DateTime? timestamp,
    this.errorMessage,
    this.pushedCreates = 0,
    this.pushedUpdates = 0,
    this.pushedDeletes = 0,
    this.pulledCreates = 0,
    this.pulledUpdates = 0,
    this.pulledDeletes = 0,
    this.conflictsResolved = 0,
    this.conflictDetails = const [],
    this.wasFullSync = false,
    this.duration,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a report for when not connected to Google Calendar
  factory SyncReport.notConnected() => SyncReport(
    status: SyncStatus.notConnected,
    errorMessage: 'Not connected to Google Calendar',
  );

  /// Create a report for when offline
  factory SyncReport.offline() =>
      SyncReport(status: SyncStatus.offline, errorMessage: 'Device is offline');

  /// Create a report for errors
  factory SyncReport.error(String message) =>
      SyncReport(status: SyncStatus.error, errorMessage: message);

  /// Create a report for skipped sync
  factory SyncReport.skipped(String reason) =>
      SyncReport(status: SyncStatus.skipped, errorMessage: reason);

  /// Whether the sync was successful
  bool get isSuccess => status == SyncStatus.success;

  /// Total number of push operations
  int get totalPushed => pushedCreates + pushedUpdates + pushedDeletes;

  /// Total number of pull operations
  int get totalPulled => pulledCreates + pulledUpdates + pulledDeletes;

  /// Whether any data was synced
  bool get hadChanges => totalPushed > 0 || totalPulled > 0;

  @override
  String toString() {
    if (!isSuccess) {
      return 'SyncReport(status: $status, error: $errorMessage)';
    }
    return 'SyncReport(status: $status, pushed: $totalPushed, pulled: $totalPulled, fullSync: $wasFullSync)';
  }

  /// Human-readable summary for UI display
  String get summary {
    switch (status) {
      case SyncStatus.success:
        if (!hadChanges) return 'Everything up to date';
        final parts = <String>[];
        if (totalPushed > 0) parts.add('$totalPushed pushed');
        if (totalPulled > 0) parts.add('$totalPulled pulled');
        return parts.join(', ');
      case SyncStatus.notConnected:
        return 'Not connected to calendar';
      case SyncStatus.offline:
        return 'Offline - changes queued';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.inProgress:
        return 'Syncing...';
      case SyncStatus.skipped:
        return 'Sync skipped';
    }
  }
}
