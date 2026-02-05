import 'package:hive/hive.dart';
import '../models/models.dart';

/// Service for persisting data to local storage using Hive
/// Handles all v2 models plus legacy Task model for migration
class StorageService {
  // Box names
  static const String _legacyTasksBoxName = 'tasks'; // v1 tasks
  static const String _signalTasksBoxName = 'signal_tasks';
  static const String _tagsBoxName = 'tags';
  static const String _settingsBoxName = 'settings';
  static const String _weeklyStatsBoxName = 'weekly_stats';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _rolloverSuggestionsBoxName = 'rollover_suggestions';

  // Settings keys
  static const String _userSettingsKey = 'user_settings';

  // ============ Box Getters ============

  /// Legacy tasks box (for migration)
  Box<Task>? get _legacyTasksBox {
    if (Hive.isBoxOpen(_legacyTasksBoxName)) {
      return Hive.box<Task>(_legacyTasksBoxName);
    }
    return null;
  }

  Box<SignalTask> get _signalTasksBox =>
      Hive.box<SignalTask>(_signalTasksBoxName);
  Box<Tag> get _tagsBox => Hive.box<Tag>(_tagsBoxName);
  Box<dynamic> get _settingsBox => Hive.box(_settingsBoxName);
  Box<WeeklyStats> get _weeklyStatsBox =>
      Hive.box<WeeklyStats>(_weeklyStatsBoxName);
  Box<CalendarSyncOperation> get _syncQueueBox =>
      Hive.box<CalendarSyncOperation>(_syncQueueBoxName);
  Box<RolloverSuggestion> get _rolloverSuggestionsBox =>
      Hive.box<RolloverSuggestion>(_rolloverSuggestionsBoxName);

  // ============ Signal Tasks ============

  /// Get all signal tasks
  List<SignalTask> getAllSignalTasks() {
    return _signalTasksBox.values.toList();
  }

  /// Get signal tasks for a specific date
  List<SignalTask> getSignalTasksForDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    return _signalTasksBox.values
        .where((task) => _isSameDay(task.scheduledDate, normalizedDate))
        .toList();
  }

  /// Get signal tasks for the last 7 days
  List<SignalTask> getSignalTasksForLastWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    return _signalTasksBox.values
        .where(
          (task) =>
              task.scheduledDate.isAfter(weekAgo) ||
              _isSameDay(task.scheduledDate, weekAgo),
        )
        .toList();
  }

  /// Get signal tasks for a date range
  List<SignalTask> getSignalTasksForDateRange(DateTime start, DateTime end) {
    return _signalTasksBox.values
        .where(
          (task) =>
              (task.scheduledDate.isAfter(start) ||
                  _isSameDay(task.scheduledDate, start)) &&
              (task.scheduledDate.isBefore(end) ||
                  _isSameDay(task.scheduledDate, end)),
        )
        .toList();
  }

  /// Get signal task count for a specific date
  int getSignalTaskCountForDate(DateTime date) {
    return getSignalTasksForDate(date).length;
  }

  /// Add a new signal task
  Future<void> addSignalTask(SignalTask task) async {
    await _signalTasksBox.put(task.id, task);
  }

  /// Update an existing signal task
  Future<void> updateSignalTask(SignalTask task) async {
    await _signalTasksBox.put(task.id, task);
  }

  /// Delete a signal task
  Future<void> deleteSignalTask(String id) async {
    await _signalTasksBox.delete(id);
  }

  /// Get a signal task by ID
  SignalTask? getSignalTask(String id) {
    return _signalTasksBox.get(id);
  }

  /// Get incomplete tasks that should be rolled over
  List<SignalTask> getIncompleteTasks(DateTime beforeDate) {
    final normalized = _normalizeDate(beforeDate);
    return _signalTasksBox.values
        .where(
          (task) =>
              !task.isComplete &&
              task.status != TaskStatus.rolled &&
              task.scheduledDate.isBefore(normalized),
        )
        .toList();
  }

  // ============ Tags ============

  /// Get all tags
  List<Tag> getAllTags() {
    return _tagsBox.values.toList();
  }

  /// Get tag by ID
  Tag? getTag(String id) {
    return _tagsBox.get(id);
  }

  /// Get multiple tags by IDs
  List<Tag> getTagsByIds(List<String> ids) {
    return ids.map((id) => _tagsBox.get(id)).whereType<Tag>().toList();
  }

  /// Add a new tag
  Future<void> addTag(Tag tag) async {
    await _tagsBox.put(tag.id, tag);
  }

  /// Update an existing tag
  Future<void> updateTag(Tag tag) async {
    await _tagsBox.put(tag.id, tag);
  }

  /// Delete a tag (only non-default tags)
  Future<void> deleteTag(String id) async {
    final tag = _tagsBox.get(id);
    if (tag != null && !tag.isDefault) {
      await _tagsBox.delete(id);
    }
  }

  /// Check if default tags exist
  bool hasDefaultTags() {
    return _tagsBox.values.any((tag) => tag.isDefault);
  }

  /// Initialize default tags if they don't exist
  Future<void> initializeDefaultTags() async {
    if (!hasDefaultTags()) {
      for (final tag in Tag.defaultTags) {
        await _tagsBox.put(tag.id, tag);
      }
    }
  }

  // ============ User Settings ============

  /// Get user settings
  UserSettings getUserSettings() {
    final settings = _settingsBox.get(_userSettingsKey);
    if (settings is UserSettings) {
      return settings;
    }
    return UserSettings.defaults;
  }

  /// Save user settings
  Future<void> saveUserSettings(UserSettings settings) async {
    await _settingsBox.put(_userSettingsKey, settings);
  }

  /// Check if onboarding is completed
  bool isOnboardingCompleted() {
    return getUserSettings().hasCompletedOnboarding;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    final settings = getUserSettings();
    await saveUserSettings(settings.copyWith(hasCompletedOnboarding: true));
  }

  // ============ Weekly Stats ============

  /// Get weekly stats for a specific week
  WeeklyStats? getWeeklyStats(DateTime weekStart) {
    final normalized = _normalizeDate(weekStart);
    final key = '${normalized.year}-${normalized.month}-${normalized.day}';
    return _weeklyStatsBox.get(key);
  }

  /// Save weekly stats
  Future<void> saveWeeklyStats(WeeklyStats stats) async {
    final normalized = _normalizeDate(stats.weekStartDate);
    final key = '${normalized.year}-${normalized.month}-${normalized.day}';
    await _weeklyStatsBox.put(key, stats);
  }

  /// Get all weekly stats
  List<WeeklyStats> getAllWeeklyStats() {
    return _weeklyStatsBox.values.toList();
  }

  // ============ Calendar Sync Queue ============

  /// Get all pending sync operations
  List<CalendarSyncOperation> getPendingSyncOperations() {
    return _syncQueueBox.values.where((op) => !op.hasExceededRetries).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Add a sync operation to the queue
  Future<void> addSyncOperation(CalendarSyncOperation operation) async {
    await _syncQueueBox.put(operation.id, operation);
  }

  /// Update a sync operation
  Future<void> updateSyncOperation(CalendarSyncOperation operation) async {
    await _syncQueueBox.put(operation.id, operation);
  }

  /// Remove a sync operation (after successful sync)
  Future<void> removeSyncOperation(String id) async {
    await _syncQueueBox.delete(id);
  }

  /// Clear all sync operations
  Future<void> clearSyncQueue() async {
    await _syncQueueBox.clear();
  }

  // ============ Rollover Suggestions ============

  /// Get pending rollover suggestions for a date
  List<RolloverSuggestion> getPendingRolloverSuggestions(DateTime forDate) {
    final normalized = _normalizeDate(forDate);
    return _rolloverSuggestionsBox.values
        .where((s) => s.isPending && _isSameDay(s.suggestedForDate, normalized))
        .toList();
  }

  /// Get all rollover suggestions
  List<RolloverSuggestion> getAllRolloverSuggestions() {
    return _rolloverSuggestionsBox.values.toList();
  }

  /// Add a rollover suggestion
  Future<void> addRolloverSuggestion(RolloverSuggestion suggestion) async {
    await _rolloverSuggestionsBox.put(suggestion.id, suggestion);
  }

  /// Update a rollover suggestion
  Future<void> updateRolloverSuggestion(RolloverSuggestion suggestion) async {
    await _rolloverSuggestionsBox.put(suggestion.id, suggestion);
  }

  /// Delete a rollover suggestion
  Future<void> deleteRolloverSuggestion(String id) async {
    await _rolloverSuggestionsBox.delete(id);
  }

  // ============ Legacy Tasks (for migration AND backward compatibility) ============

  /// Get all legacy tasks (v1)
  List<Task> getLegacyTasks() {
    return _legacyTasksBox?.values.toList() ?? [];
  }

  /// Check if legacy tasks exist
  bool hasLegacyTasks() {
    return _legacyTasksBox != null && _legacyTasksBox!.isNotEmpty;
  }

  /// Clear legacy tasks after migration
  Future<void> clearLegacyTasks() async {
    await _legacyTasksBox?.clear();
  }

  // ============ Legacy API (backward compatibility during transition) ============
  // These methods maintain compatibility with the existing TaskProvider
  // They will be removed once TaskProvider is fully migrated

  /// @deprecated Use getAllSignalTasks() instead
  List<Task> getAllTasks() {
    return _legacyTasksBox?.values.toList() ?? [];
  }

  /// @deprecated Use getSignalTasksForDate() instead
  List<Task> getTasksForDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    return (_legacyTasksBox?.values ?? [])
        .where((task) => _isSameDay(task.date, normalizedDate))
        .toList();
  }

  /// @deprecated Use getSignalTasksForLastWeek() instead
  List<Task> getTasksForLastWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return (_legacyTasksBox?.values ?? [])
        .where(
          (task) =>
              task.date.isAfter(weekAgo) || _isSameDay(task.date, weekAgo),
        )
        .toList();
  }

  /// @deprecated Use addSignalTask() instead
  Future<void> addTask(Task task) async {
    await _legacyTasksBox?.put(task.id, task);
  }

  /// @deprecated Use updateSignalTask() instead
  Future<void> updateTask(Task task) async {
    await _legacyTasksBox?.put(task.id, task);
  }

  /// @deprecated Use deleteSignalTask() instead
  Future<void> deleteTask(String id) async {
    await _legacyTasksBox?.delete(id);
  }

  /// @deprecated Use getSignalTaskCountForDate() instead
  int getTodaySignalCount() {
    final today = _normalizeDate(DateTime.now());
    return (_legacyTasksBox?.values ?? [])
        .where(
          (task) =>
              _isSameDay(task.date, today) && task.type == TaskType.signal,
        )
        .length;
  }

  // ============ Data Version ============

  /// Get current data version
  int getDataVersion() {
    return getUserSettings().dataVersion;
  }

  /// Set data version
  Future<void> setDataVersion(int version) async {
    final settings = getUserSettings();
    await saveUserSettings(settings.copyWith(dataVersion: version));
  }

  // ============ Simple Key-Value Storage ============

  /// Get a boolean value from settings box
  bool? getBool(String key) {
    final value = _settingsBox.get(key);
    if (value is bool) return value;
    return null;
  }

  /// Set a boolean value in settings box
  Future<void> setBool(String key, bool value) async {
    await _settingsBox.put(key, value);
  }

  /// Get an integer value from settings box
  int? getInt(String key) {
    final value = _settingsBox.get(key);
    if (value is int) return value;
    return null;
  }

  /// Set an integer value in settings box
  Future<void> setInt(String key, int value) async {
    await _settingsBox.put(key, value);
  }

  /// Get a string value from settings box
  String? getString(String key) {
    final value = _settingsBox.get(key);
    if (value is String) return value;
    return null;
  }

  /// Set a string value in settings box
  Future<void> setString(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  // ============ Utility Methods ============

  /// Normalize date to midnight (removes time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ============ Export / Backup ============

  /// Export all data as a map (for backup)
  Map<String, dynamic> exportAllData() {
    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'signalTasks': _signalTasksBox.values
          .map((t) => _signalTaskToMap(t))
          .toList(),
      'tags': _tagsBox.values.map((t) => _tagToMap(t)).toList(),
      'settings': _userSettingsToMap(getUserSettings()),
      'weeklyStats': _weeklyStatsBox.values
          .map((s) => _weeklyStatsToMap(s))
          .toList(),
    };
  }

  // Serialization helpers (for export)
  Map<String, dynamic> _signalTaskToMap(SignalTask task) {
    return {
      'id': task.id,
      'title': task.title,
      'estimatedMinutes': task.estimatedMinutes,
      'tagIds': task.tagIds,
      'status': task.status.index,
      'scheduledDate': task.scheduledDate.toIso8601String(),
      'isComplete': task.isComplete,
      'createdAt': task.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _tagToMap(Tag tag) {
    return {
      'id': tag.id,
      'name': tag.name,
      'colorHex': tag.colorHex,
      'isDefault': tag.isDefault,
      'createdAt': tag.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _userSettingsToMap(UserSettings settings) {
    return {
      'autoStartTasks': settings.autoStartTasks,
      'autoEndTasks': settings.autoEndTasks,
      'notificationBeforeEndMinutes': settings.notificationBeforeEndMinutes,
      'hasCompletedOnboarding': settings.hasCompletedOnboarding,
      'defaultSignalColorHex': settings.defaultSignalColorHex,
      'focusHoursPerDay': settings.focusHoursPerDay,
    };
  }

  Map<String, dynamic> _weeklyStatsToMap(WeeklyStats stats) {
    return {
      'weekStartDate': stats.weekStartDate.toIso8601String(),
      'totalSignalMinutes': stats.totalSignalMinutes,
      'totalFocusMinutes': stats.totalFocusMinutes,
      'completedTasksCount': stats.completedTasksCount,
      'tagBreakdown': stats.tagBreakdown,
    };
  }
}
