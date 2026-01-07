import 'package:hive/hive.dart';

part 'calendar_sync_operation.g.dart';

/// Type of calendar sync operation
@HiveType(typeId: 18)
enum SyncOperationType {
  @HiveField(0)
  create,
  @HiveField(1)
  update,
  @HiveField(2)
  delete,
}

/// A queued operation for syncing with Google Calendar
/// Used for offline support - operations are queued and synced when online
@HiveType(typeId: 19)
class CalendarSyncOperation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  SyncOperationType type;

  @HiveField(2)
  String taskId;

  @HiveField(3)
  String? timeSlotId; // For slot-specific operations

  @HiveField(4)
  String? googleCalendarEventId; // For update/delete operations

  @HiveField(5)
  String? eventTitle;

  @HiveField(6)
  DateTime? eventStart;

  @HiveField(7)
  DateTime? eventEnd;

  @HiveField(8)
  String? eventColorHex;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  int retryCount;

  @HiveField(11)
  String? lastError; // For debugging failed syncs

  CalendarSyncOperation({
    required this.id,
    required this.type,
    required this.taskId,
    this.timeSlotId,
    this.googleCalendarEventId,
    this.eventTitle,
    this.eventStart,
    this.eventEnd,
    this.eventColorHex,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Increment retry count and update last error
  void recordFailure(String error) {
    retryCount++;
    lastError = error;
  }

  /// Whether this operation has exceeded max retries
  bool get hasExceededRetries => retryCount >= 5;

  /// Create a CREATE operation
  static CalendarSyncOperation createEvent({
    required String id,
    required String taskId,
    required String timeSlotId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? colorHex,
  }) {
    return CalendarSyncOperation(
      id: id,
      type: SyncOperationType.create,
      taskId: taskId,
      timeSlotId: timeSlotId,
      eventTitle: title,
      eventStart: start,
      eventEnd: end,
      eventColorHex: colorHex,
      createdAt: DateTime.now(),
    );
  }

  /// Create an UPDATE operation
  static CalendarSyncOperation updateEvent({
    required String id,
    required String taskId,
    required String timeSlotId,
    required String googleCalendarEventId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? colorHex,
  }) {
    return CalendarSyncOperation(
      id: id,
      type: SyncOperationType.update,
      taskId: taskId,
      timeSlotId: timeSlotId,
      googleCalendarEventId: googleCalendarEventId,
      eventTitle: title,
      eventStart: start,
      eventEnd: end,
      eventColorHex: colorHex,
      createdAt: DateTime.now(),
    );
  }

  /// Create a DELETE operation
  static CalendarSyncOperation deleteEvent({
    required String id,
    required String taskId,
    String? timeSlotId,
    required String googleCalendarEventId,
  }) {
    return CalendarSyncOperation(
      id: id,
      type: SyncOperationType.delete,
      taskId: taskId,
      timeSlotId: timeSlotId,
      googleCalendarEventId: googleCalendarEventId,
      createdAt: DateTime.now(),
    );
  }

  /// Create a copy with optional overrides
  CalendarSyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    String? taskId,
    String? timeSlotId,
    String? googleCalendarEventId,
    String? eventTitle,
    DateTime? eventStart,
    DateTime? eventEnd,
    String? eventColorHex,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return CalendarSyncOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      googleCalendarEventId:
          googleCalendarEventId ?? this.googleCalendarEventId,
      eventTitle: eventTitle ?? this.eventTitle,
      eventStart: eventStart ?? this.eventStart,
      eventEnd: eventEnd ?? this.eventEnd,
      eventColorHex: eventColorHex ?? this.eventColorHex,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
