import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/google_calendar_event.dart';
import '../models/signal_task.dart';
import '../models/time_slot.dart';
import '../models/sync_result.dart';

/// Service for Google Calendar OAuth and API operations
class GoogleCalendarService {
  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  // Storage keys
  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _tokenExpiryKey = 'google_token_expiry';
  static const _selectedCalendarKey = 'google_selected_calendar';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true, // Clear if encryption fails on older devices
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Google Sign In configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gcal.CalendarApi.calendarReadonlyScope,
      gcal.CalendarApi.calendarEventsScope,
    ],
  );

  // Cached API client
  gcal.CalendarApi? _calendarApi;
  GoogleSignInAccount? _currentUser;
  _GoogleAuthClient? _authClient;

  // State
  bool _isInitialized = false;
  List<String>? _selectedCalendarId;

  /// Initialize the service (call on app start)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if user was previously signed in
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _setupApiClient();
      }

      // Load selected calendars as JSON string
      final calendarsJson = await _secureStorage.read(
        key: _selectedCalendarKey,
      );
      if (calendarsJson != null) {
        _selectedCalendarId = List<String>.from(jsonDecode(calendarsJson));
      } else {
        _selectedCalendarId = null;
      }

      _isInitialized = true;
    } catch (e) {
      _logDebug('Initialization error', sensitive: true);
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Debug logging helper - redacts sensitive information
  void _logDebug(String message, {bool sensitive = false}) {
    if (kDebugMode) {
      if (sensitive) {
        debugPrint('[GoogleCalendar] $message (details redacted)');
      } else {
        debugPrint('[GoogleCalendar] $message');
      }
    }
  }

  /// Whether user is connected to Google Calendar
  bool get isConnected => _currentUser != null && _calendarApi != null;

  /// Current user's email
  String? get userEmail => _currentUser?.email;

  /// Current user's display name
  String? get userDisplayName => _currentUser?.displayName;

  /// Selected calendar ID (null = primary)
  List<String> get selectedCalendarId => _selectedCalendarId ?? ['primary'];

  /// Get the primary calendar for write operations (first in selection list)
  String get primaryCalendarId =>
      selectedCalendarId.isNotEmpty ? selectedCalendarId.first : 'primary';

  /// Sign in to Google
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      await _setupApiClient();
      return true;
    } catch (e) {
      _logDebug('Sign-in error', sensitive: true);
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    // Close existing HTTP client to prevent memory leak
    _authClient?.close();
    _authClient = null;

    await _googleSignIn.signOut();
    await _clearTokens();
    _currentUser = null;
    _calendarApi = null;
    _selectedCalendarId = null;
  }

  /// Refresh the authentication token
  Future<bool> refreshToken() async {
    try {
      if (_currentUser == null) return false;
      await _currentUser!.clearAuthCache();
      await _setupApiClient();
      return true;
    } catch (e) {
      _logDebug('Token refresh failed', sensitive: true);
      return false;
    }
  }

  /// Check if token is valid (not expired)
  Future<bool> isTokenValid() async {
    final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
    if (expiryStr == null) return false;

    try {
      final expiry = DateTime.parse(expiryStr);
      // Consider token invalid if it expires within 5 minutes
      return DateTime.now().isBefore(
        expiry.subtract(const Duration(minutes: 5)),
      );
    } catch (_) {
      return false;
    }
  }

  /// Set up the Calendar API client with authentication
  Future<void> _setupApiClient() async {
    if (_currentUser == null) return;

    try {
      // Close old client if exists
      _authClient?.close();

      final auth = await _currentUser!.authentication;

      // Calculate token expiry (Google access tokens typically last 1 hour)
      final expiry = DateTime.now().add(const Duration(hours: 1));

      // Store tokens securely with expiry
      await _storeTokens(
        accessToken: auth.accessToken!,
        idToken: auth.idToken,
        expiry: expiry,
      );

      // Create authenticated HTTP client
      _authClient = _GoogleAuthClient(auth);
      _calendarApi = gcal.CalendarApi(_authClient!);
    } catch (e) {
      _logDebug('Error setting up API client', sensitive: true);
      _calendarApi = null;
    }
  }

  /// Store tokens securely with expiry
  Future<void> _storeTokens({
    required String accessToken,
    String? idToken,
    required DateTime expiry,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(
      key: _tokenExpiryKey,
      value: expiry.toIso8601String(),
    );
    if (idToken != null) {
      await _secureStorage.write(key: 'google_id_token', value: idToken);
    }
  }

  /// Clear stored tokens
  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _selectedCalendarKey);
    await _secureStorage.delete(key: 'google_id_token');
  }

  /// Set the selected calendars (replaces any previous selection)
  Future<void> setSelectedCalendars(List<String> calendarIds) async {
    _selectedCalendarId = calendarIds;
    await _secureStorage.write(
      key: _selectedCalendarKey,
      value: jsonEncode(calendarIds),
    );
  }

  /// Add a calendar to the selection
  Future<void> addSelectedCalendar(String calendarId) async {
    final list = _selectedCalendarId ?? <String>[];
    if (!list.contains(calendarId)) {
      list.add(calendarId);
      await _secureStorage.write(
        key: _selectedCalendarKey,
        value: jsonEncode(list),
      );
      _selectedCalendarId = List<String>.from(list);
    }
  }

  /// Remove a calendar from the selection
  Future<void> removeSelectedCalendar(String calendarId) async {
    final list = _selectedCalendarId ?? <String>[];
    list.remove(calendarId);
    await _secureStorage.write(
      key: _selectedCalendarKey,
      value: jsonEncode(list),
    );
    _selectedCalendarId = List<String>.from(list);
  }

  // ============ Calendar Operations ============

  /// Get list of user's calendars
  Future<List<gcal.CalendarListEntry>> getCalendarList() async {
    if (_calendarApi == null) {
      throw Exception('Not connected to Google Calendar');
    }

    final response = await _calendarApi!.calendarList.list();
    return response.items ?? [];
  }

  /// Get events for a specific date
  Future<List<GoogleCalendarEvent>> getEventsForDate(DateTime date) async {
    if (_calendarApi == null) return [];

    // Check token validity and refresh if needed
    if (!await isTokenValid()) {
      await refreshToken();
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final allEvents = <GoogleCalendarEvent>[];

    for (final calendarId in selectedCalendarId) {
      try {
        final events = await _calendarApi!.events.list(
          calendarId,
          timeMin: startOfDay.toUtc(),
          timeMax: endOfDay.toUtc(),
          singleEvents: true,
          orderBy: 'startTime',
        );

        allEvents.addAll(
          (events.items ?? []).map(
            (e) =>
                GoogleCalendarEvent.fromGoogleEvent(_eventToMap(e), calendarId),
          ),
        );
      } catch (e) {
        _logDebug(
          'Error fetching events for calendar $calendarId',
          sensitive: true,
        );
      }
    }
    _logDebug(
      'Loaded ${allEvents.length} events for ${date.toIso8601String().split('T')[0]} from ${selectedCalendarId.length} calendars',
    );
    return allEvents;
  }

  /// Get events for a date range
  Future<List<GoogleCalendarEvent>> getEventsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    if (_calendarApi == null) return [];

    // Check token validity and refresh if needed
    if (!await isTokenValid()) {
      await refreshToken();
    }

    final allEvents = <GoogleCalendarEvent>[];

    for (final calendarId in selectedCalendarId) {
      try {
        final events = await _calendarApi!.events.list(
          calendarId,
          timeMin: start.toUtc(),
          timeMax: end.toUtc(),
          singleEvents: true,
          orderBy: 'startTime',
        );

        allEvents.addAll(
          (events.items ?? []).map(
            (e) =>
                GoogleCalendarEvent.fromGoogleEvent(_eventToMap(e), calendarId),
          ),
        );
      } catch (e) {
        _logDebug(
          'Error fetching events for range on calendar $calendarId',
          sensitive: true,
        );
      }
    }
    return allEvents;
  }

  /// Create a calendar event for a Signal task time slot
  Future<String?> createEventForTimeSlot({
    required SignalTask task,
    required TimeSlot slot,
    String? colorId,
  }) async {
    if (_calendarApi == null) return null;

    final event = gcal.Event()
      ..summary = task.title
      ..description =
          'Signal task from Signal/Noise\nsignal-noise-task:${task.id}'
      ..start = (gcal.EventDateTime()..dateTime = slot.plannedStartTime.toUtc())
      ..end = (gcal.EventDateTime()..dateTime = slot.plannedEndTime.toUtc())
      ..colorId = colorId ?? '9'; // Default to Blueberry (blue)

    try {
      final created = await _calendarApi!.events.insert(
        event,
        primaryCalendarId,
      );
      _logDebug('Created event: ${created.id}');
      return created.id;
    } catch (e) {
      _logDebug('Error creating event', sensitive: true);
      return null;
    }
  }

  /// Update a calendar event (e.g., when actual times differ from planned)
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? colorId,
    String? calendarId,
  }) async {
    if (_calendarApi == null) return false;

    try {
      final targetCalendarId = calendarId ?? primaryCalendarId;
      // Fetch existing event
      final existing = await _calendarApi!.events.get(
        targetCalendarId,
        eventId,
      );

      // Update fields
      if (title != null) existing.summary = title;
      if (startTime != null) {
        existing.start = gcal.EventDateTime()..dateTime = startTime.toUtc();
      }
      if (endTime != null) {
        existing.end = gcal.EventDateTime()..dateTime = endTime.toUtc();
      }
      if (colorId != null) existing.colorId = colorId;

      await _calendarApi!.events.update(existing, targetCalendarId, eventId);
      _logDebug('Updated event: $eventId');
      return true;
    } catch (e) {
      _logDebug('Error updating event', sensitive: true);
      return false;
    }
  }

  /// Delete a calendar event
  Future<bool> deleteEvent(String eventId) async {
    if (_calendarApi == null) return false;

    try {
      await _calendarApi!.events.delete(primaryCalendarId, eventId);
      _logDebug('Deleted event: $eventId');
      return true;
    } catch (e) {
      _logDebug('Error deleting event', sensitive: true);
      return false;
    }
  }

  /// Mark an existing Google Calendar event as Signal (update its color)
  Future<bool> markEventAsSignal(String eventId, {String? calendarId}) async {
    return updateEvent(
      eventId: eventId,
      colorId: '9',
      calendarId: calendarId,
    ); // Blueberry = Signal
  }

  /// Get a single event by ID
  Future<GoogleCalendarEvent?> getEvent(String eventId) async {
    if (_calendarApi == null) return null;

    try {
      final event = await _calendarApi!.events.get(primaryCalendarId, eventId);
      return GoogleCalendarEvent.fromGoogleEvent(
        _eventToMap(event),
        primaryCalendarId,
      );
    } catch (e) {
      _logDebug('Error fetching single event', sensitive: true);
      return null;
    }
  }

  // ============ Sync Operations ============

  /// Perform a full sync - fetches all events with pagination
  /// Returns a FullSyncResult containing all events and a syncToken for future incremental syncs
  ///
  /// IMPORTANT: To get a syncToken, we cannot use orderBy, q, or other incompatible parameters.
  /// See: https://developers.google.com/calendar/api/guides/sync
  /// Note: Sync operations use the primary (first selected) calendar for syncToken compatibility
  Future<FullSyncResult> performFullSync({
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    if (_calendarApi == null) {
      throw Exception('Not connected to Google Calendar');
    }

    // Check token validity and refresh if needed
    if (!await isTokenValid()) {
      await refreshToken();
    }

    final allEvents = <GoogleCalendarEvent>[];
    String? pageToken;
    String? syncToken;

    _logDebug('Starting full sync...');

    try {
      do {
        // NOTE: Cannot use orderBy with sync - it prevents syncToken from being returned
        // Also cannot use singleEvents:true as it's incompatible with syncToken
        final response = await _calendarApi!.events.list(
          primaryCalendarId,
          timeMin: timeMin?.toUtc(),
          timeMax: timeMax?.toUtc(),
          maxResults: 250, // Max allowed by API
          pageToken: pageToken,
          showDeleted: true, // Include deleted events for proper sync
        );

        // Convert and add events (skip cancelled events for initial sync display)
        for (final event in response.items ?? []) {
          if (event.status != 'cancelled') {
            allEvents.add(
              GoogleCalendarEvent.fromGoogleEvent(
                _eventToMap(event),
                primaryCalendarId,
              ),
            );
          }
        }

        pageToken = response.nextPageToken;

        // syncToken is only on the LAST page of results
        if (response.nextSyncToken != null) {
          syncToken = response.nextSyncToken;
        }

        _logDebug(
          'Fetched ${response.items?.length ?? 0} events, hasMore: ${pageToken != null}, hasSyncToken: ${response.nextSyncToken != null}',
        );
      } while (pageToken != null);

      _logDebug('Full sync complete: ${allEvents.length} total events');

      if (syncToken == null) {
        throw Exception('No sync token received from Google Calendar');
      }

      return FullSyncResult(events: allEvents, syncToken: syncToken);
    } catch (e) {
      _logDebug('Full sync error', sensitive: true);
      rethrow;
    }
  }

  /// Perform incremental sync - fetches only changes since the last sync
  /// Uses the syncToken to get only modified/deleted events
  /// Throws SyncTokenExpiredException if the token is invalid (HTTP 410)
  /// Note: Sync operations use primary (first selected) calendar for syncToken compatibility
  Future<IncrementalSyncResult> performIncrementalSync(String syncToken) async {
    if (_calendarApi == null) {
      throw Exception('Not connected to Google Calendar');
    }

    // Check token validity and refresh if needed
    if (!await isTokenValid()) {
      await refreshToken();
    }

    final changedEvents = <GoogleCalendarEvent>[];
    final deletedEventIds = <String>[];
    String? pageToken;
    String? newSyncToken;

    _logDebug('Starting incremental sync with token...');

    try {
      do {
        final response = await _calendarApi!.events.list(
          primaryCalendarId,
          syncToken: syncToken,
          pageToken: pageToken,
          showDeleted: true, // Important: include deleted events
        );

        // Process each event
        for (final event in response.items ?? []) {
          if (event.status == 'cancelled') {
            // Event was deleted
            if (event.id != null) {
              deletedEventIds.add(event.id!);
            }
          } else {
            // Event was created or modified
            changedEvents.add(
              GoogleCalendarEvent.fromGoogleEvent(
                _eventToMap(event),
                primaryCalendarId,
              ),
            );
          }
        }

        pageToken = response.nextPageToken;

        // syncToken is only returned on the LAST page of results
        if (response.nextSyncToken != null) {
          newSyncToken = response.nextSyncToken;
        }

        _logDebug(
          'Incremental: ${response.items?.length ?? 0} changes, hasMore: ${pageToken != null}, hasSyncToken: ${response.nextSyncToken != null}',
        );
      } while (pageToken != null);

      _logDebug(
        'Incremental sync complete: ${changedEvents.length} changed, ${deletedEventIds.length} deleted',
      );

      if (newSyncToken == null) {
        throw Exception('No sync token received from Google Calendar');
      }

      return IncrementalSyncResult(
        changedEvents: changedEvents,
        deletedEventIds: deletedEventIds,
        newSyncToken: newSyncToken,
      );
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status == 410) {
        // Sync token is invalid - need to perform full sync
        _logDebug('Sync token expired (HTTP 410)');
        throw SyncTokenExpiredException('Sync token expired or invalid');
      }
      rethrow;
    } catch (e) {
      _logDebug('Incremental sync error', sensitive: true);
      rethrow;
    }
  }

  // Helper to convert gcal.Event to Map for parsing
  Map<String, dynamic> _eventToMap(gcal.Event event) {
    return {
      'id': event.id,
      'summary': event.summary,
      'description': event.description,
      'colorId': event.colorId,
      'start': {
        'dateTime': event.start?.dateTime?.toIso8601String(),
        'date': event.start?.date?.toString(),
      },
      'end': {
        'dateTime': event.end?.dateTime?.toIso8601String(),
        'date': event.end?.date?.toString(),
      },
    };
  }
}

/// Custom HTTP client that adds authentication headers
class _GoogleAuthClient extends http.BaseClient {
  final GoogleSignInAuthentication _auth;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._auth);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer ${_auth.accessToken}';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
