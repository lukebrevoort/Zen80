import 'package:flutter/material.dart';

/// Represents a Google Calendar event (for display only)
/// We don't persist these - they're fetched fresh from the API
class GoogleCalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? colorId; // Google's color ID (1-11)
  final bool isAllDay;
  final String calendarId;

  // For linking to Signal tasks
  final String? linkedSignalTaskId; // If this event was created by us

  GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.colorId,
    this.isAllDay = false,
    required this.calendarId,
    this.linkedSignalTaskId,
  });

  /// Parse from Google Calendar API response
  factory GoogleCalendarEvent.fromGoogleEvent(
    Map<String, dynamic> json,
    String calendarId,
  ) {
    // Handle all-day vs timed events
    final start = json['start'] as Map<String, dynamic>?;
    final end = json['end'] as Map<String, dynamic>?;

    DateTime startTime;
    DateTime endTime;
    bool isAllDay = false;

    if (start?['dateTime'] != null) {
      // Parse and convert to local time to ensure correct display
      // Google Calendar API may return UTC or timezone-aware ISO strings
      startTime = DateTime.parse(start!['dateTime'] as String).toLocal();
      endTime = DateTime.parse(end!['dateTime'] as String).toLocal();
    } else if (start?['date'] != null) {
      // All-day event - date only
      startTime = DateTime.parse(start!['date'] as String);
      endTime = DateTime.parse(end!['date'] as String);
      isAllDay = true;
    } else {
      // Fallback to now if no valid dates
      startTime = DateTime.now();
      endTime = DateTime.now().add(const Duration(hours: 1));
    }

    // Check if this event was created by Signal/Noise
    String? linkedTaskId;
    final description = json['description'] as String?;
    if (description?.contains('signal-noise-task:') == true) {
      final regex = RegExp(r'signal-noise-task:(\S+)');
      final match = regex.firstMatch(description!);
      linkedTaskId = match?.group(1);
    }

    return GoogleCalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['summary'] as String? ?? '(No title)',
      startTime: startTime,
      endTime: endTime,
      description: description,
      colorId: json['colorId'] as String?,
      isAllDay: isAllDay,
      calendarId: calendarId,
      linkedSignalTaskId: linkedTaskId,
    );
  }

  /// Whether this event was created by Signal/Noise
  bool get isSignalTask => linkedSignalTaskId != null;

  /// Duration of the event
  Duration get duration => endTime.difference(startTime);

  /// Duration in minutes
  int get durationMinutes => duration.inMinutes;

  /// Get color for display (map Google's color IDs to Flutter colors)
  Color get color {
    // Google Calendar color IDs mapped to colors
    switch (colorId) {
      case '1':
        return const Color(0xFF7986CB); // Lavender
      case '2':
        return const Color(0xFF33B679); // Sage
      case '3':
        return const Color(0xFF8E24AA); // Grape
      case '4':
        return const Color(0xFFE67C73); // Flamingo
      case '5':
        return const Color(0xFFF6BF26); // Banana
      case '6':
        return const Color(0xFFFF8A65); // Tangerine
      case '7':
        return const Color(0xFF039BE5); // Peacock
      case '8':
        return const Color(0xFF616161); // Graphite
      case '9':
        return const Color(0xFF3F51B5); // Blueberry
      case '10':
        return const Color(0xFF0B8043); // Basil
      case '11':
        return const Color(0xFFD50000); // Tomato
      default:
        return const Color(0xFF9E9E9E); // Default gray
    }
  }

  /// Get color name for display
  String get colorName {
    switch (colorId) {
      case '1':
        return 'Lavender';
      case '2':
        return 'Sage';
      case '3':
        return 'Grape';
      case '4':
        return 'Flamingo';
      case '5':
        return 'Banana';
      case '6':
        return 'Tangerine';
      case '7':
        return 'Peacock';
      case '8':
        return 'Graphite';
      case '9':
        return 'Blueberry';
      case '10':
        return 'Basil';
      case '11':
        return 'Tomato';
      default:
        return 'Default';
    }
  }

  /// Check if event overlaps with a time range
  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return startTime.isBefore(rangeEnd) && endTime.isAfter(rangeStart);
  }

  /// Check if event contains a specific time
  bool containsTime(DateTime time) {
    return !time.isBefore(startTime) && time.isBefore(endTime);
  }

  /// Create a copy with optional overrides
  GoogleCalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? colorId,
    bool? isAllDay,
    String? calendarId,
    String? linkedSignalTaskId,
  }) {
    return GoogleCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      colorId: colorId ?? this.colorId,
      isAllDay: isAllDay ?? this.isAllDay,
      calendarId: calendarId ?? this.calendarId,
      linkedSignalTaskId: linkedSignalTaskId ?? this.linkedSignalTaskId,
    );
  }

  @override
  String toString() {
    return 'GoogleCalendarEvent(id: $id, title: $title, '
        'start: $startTime, end: $endTime, isSignal: $isSignalTask)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleCalendarEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
