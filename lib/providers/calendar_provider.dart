import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../models/google_calendar_event.dart';
import '../services/google_calendar_service.dart';
import '../services/sync_service.dart';

/// Connection status for Google Calendar
enum CalendarConnectionStatus { disconnected, connecting, connected, error }

/// Provider for Google Calendar state
class CalendarProvider extends ChangeNotifier {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  final SyncService _syncService = SyncService();

  CalendarConnectionStatus _status = CalendarConnectionStatus.disconnected;
  List<GoogleCalendarEvent> _events = [];
  List<gcal.CalendarListEntry> _calendars = [];
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  int _pendingSyncCount = 0;
  bool _isLoading = false;

  CalendarProvider() {
    _initialize();
  }

  /// Initialize provider
  Future<void> _initialize() async {
    await _calendarService.initialize();
    await _syncService.initialize();

    // Set up sync callbacks
    _syncService.onQueueUpdated = (count) {
      _pendingSyncCount = count;
      notifyListeners();
    };

    if (_calendarService.isConnected) {
      _status = CalendarConnectionStatus.connected;
      await loadCalendars();
      await loadEventsForDate(_selectedDate);

      // Perform initial two-way sync on startup
      performSync();
    }

    notifyListeners();
  }

  // ============ Getters ============

  CalendarConnectionStatus get status => _status;
  bool get isConnected => _status == CalendarConnectionStatus.connected;
  List<GoogleCalendarEvent> get events => List.unmodifiable(_events);
  List<gcal.CalendarListEntry> get calendars => List.unmodifiable(_calendars);
  DateTime get selectedDate => _selectedDate;
  String? get errorMessage => _errorMessage;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get userEmail => _calendarService.userEmail;
  List<String> get selectedCalendarIds => _calendarService.selectedCalendarId;

  /// Events that are NOT linked to Signal tasks (external events)
  List<GoogleCalendarEvent> get externalEvents =>
      _events.where((e) => !e.isSignalTask).toList();

  /// Events that ARE linked to Signal tasks
  List<GoogleCalendarEvent> get signalEvents =>
      _events.where((e) => e.isSignalTask).toList();

  /// Get events that overlap with a given time range
  List<GoogleCalendarEvent> getEventsInRange(DateTime start, DateTime end) {
    return _events.where((e) {
      return e.startTime.isBefore(end) && e.endTime.isAfter(start);
    }).toList();
  }

  /// Check if a time slot would conflict with existing events
  bool hasConflict(DateTime start, DateTime end) {
    return _events.any((e) => e.overlaps(start, end));
  }

  // ============ Connection ============

  /// Connect to Google Calendar
  Future<bool> connect() async {
    _status = CalendarConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _calendarService.signIn();

      if (success) {
        _status = CalendarConnectionStatus.connected;
        await loadCalendars();
        await loadEventsForDate(_selectedDate);
      } else {
        _status = CalendarConnectionStatus.disconnected;
      }

      notifyListeners();
      return success;
    } catch (e) {
      _status = CalendarConnectionStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from Google Calendar
  Future<void> disconnect() async {
    await _calendarService.signOut();
    _status = CalendarConnectionStatus.disconnected;
    _events = [];
    _calendars = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ============ Calendars ============

  /// Load list of user's calendars
  Future<void> loadCalendars() async {
    if (!isConnected) return;

    try {
      _calendars = await _calendarService.getCalendarList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading calendars: $e');
    }
  }

  /// Set selected calendars (replaces any previous selection)
  Future<void> setCalendars(List<String> calendarIds) async {
    await _calendarService.setSelectedCalendars(calendarIds);
    await loadEventsForDate(_selectedDate);
  }

  /// Toggle a calendar in the selection
  Future<void> toggleCalendar(String calendarId) async {
    final current = selectedCalendarIds;
    if (current.contains(calendarId)) {
      if (current.length > 1) {
        // Don't allow deselecting the last calendar
        await _calendarService.removeSelectedCalendar(calendarId);
      }
    } else {
      await _calendarService.addSelectedCalendar(calendarId);
    }
    await loadEventsForDate(_selectedDate);
  }

  /// Get display name(s) for currently selected calendars
  String getSelectedCalendarNames() {
    if (selectedCalendarIds.isEmpty) return 'None';

    final names = selectedCalendarIds.map((id) {
      try {
        final calendar = _calendars.firstWhere((c) => c.id == id);
        return calendar.summary ?? 'Unnamed';
      } catch (_) {
        return 'Unknown';
      }
    }).toList();

    if (names.length == 1) {
      return names.first;
    } else if (names.length == 2) {
      return '${names.first} + 1 more';
    } else {
      return '${names.length} calendars';
    }
  }

  // ============ Events ============

  /// Load events for a specific date
  Future<void> loadEventsForDate(DateTime date) async {
    if (!isConnected) return;

    _selectedDate = date;
    _isLoading = true;
    notifyListeners();

    try {
      _events = await _calendarService.getEventsForDate(date);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load calendar events';
      debugPrint('Error loading events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load events for a date range
  Future<List<GoogleCalendarEvent>> loadEventsForRange(
    DateTime start,
    DateTime end,
  ) async {
    if (!isConnected) return [];

    try {
      return await _calendarService.getEventsForDateRange(start, end);
    } catch (e) {
      debugPrint('Error loading events for range: $e');
      return [];
    }
  }

  /// Refresh events for current date
  Future<void> refresh() async {
    await loadEventsForDate(_selectedDate);
  }

  /// Mark a Google Calendar event as a Signal task
  Future<bool> markEventAsSignal(String eventId, {String? calendarId}) async {
    if (!isConnected) return false;

    try {
      final success = await _calendarService.markEventAsSignal(
        eventId,
        calendarId: calendarId,
      );
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error marking event as signal: $e');
      return false;
    }
  }

  // ============ Sync ============

  /// Force process the sync queue
  Future<void> forceSync() async {
    await _syncService.processQueue();
  }

  /// Perform a two-way sync with Google Calendar
  /// This pushes local changes and pulls remote changes
  Future<void> performSync({bool forceFullSync = false}) async {
    if (!isConnected) return;

    try {
      final report = await _syncService.performSync(
        forceFullSync: forceFullSync,
      );

      // If there were changes, refresh the events
      if (report.hadChanges) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Error performing sync: $e');
    }
  }

  /// Get sync service for external access (e.g., SignalTaskProvider)
  SyncService get syncService => _syncService;

  /// Get calendar service for external access
  GoogleCalendarService get calendarService => _calendarService;

  /// Set a callback to be called when remote sync modifies Signal tasks
  /// This allows SignalTaskProvider to refresh its cached state
  void setOnSignalTasksChanged(void Function()? callback) {
    _syncService.onSignalTasksChanged = callback;
  }
}
