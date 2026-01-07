import 'package:flutter/foundation.dart';
import '../models/rollover_suggestion.dart';
import '../models/signal_task.dart';
import '../services/rollover_service.dart';
import '../services/storage_service.dart';

/// Provider for managing rollover suggestions state
///
/// Handles detection of incomplete tasks, generation of rollover suggestions,
/// and processing user decisions (accept/modify/dismiss).
class RolloverProvider extends ChangeNotifier {
  final RolloverService _rolloverService;
  final StorageService _storageService;

  List<RolloverSuggestion> _pendingSuggestions = [];
  bool _isLoading = false;
  bool _hasCheckedToday = false;
  String? _errorMessage;

  RolloverProvider(this._storageService) : _rolloverService = RolloverService();

  // ============ Getters ============

  /// List of pending rollover suggestions for today
  List<RolloverSuggestion> get pendingSuggestions =>
      List.unmodifiable(_pendingSuggestions);

  /// Whether there are pending suggestions to show
  bool get hasPendingSuggestions => _pendingSuggestions.isNotEmpty;

  /// Number of pending suggestions
  int get pendingCount => _pendingSuggestions.length;

  /// Whether the provider is currently loading
  bool get isLoading => _isLoading;

  /// Whether we've already checked for suggestions today
  bool get hasCheckedToday => _hasCheckedToday;

  /// Error message if something went wrong
  String? get errorMessage => _errorMessage;

  /// Total suggested minutes across all pending suggestions
  int get totalSuggestedMinutes =>
      _pendingSuggestions.fold(0, (sum, s) => sum + s.suggestedMinutes);

  /// Formatted total suggested time
  String get formattedTotalSuggestedTime {
    final hours = totalSuggestedMinutes ~/ 60;
    final mins = totalSuggestedMinutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  // ============ Initialization ============

  /// Check for rollover suggestions on app launch
  ///
  /// This should be called once when the app starts to detect
  /// incomplete tasks from previous days.
  Future<void> checkForRolloverSuggestions() async {
    if (_hasCheckedToday) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final today = _normalizeDate(DateTime.now());

      // First, check for any existing pending suggestions in storage
      final existingSuggestions = _storageService.getPendingRolloverSuggestions(
        today,
      );

      if (existingSuggestions.isNotEmpty) {
        // We already have pending suggestions from a previous check
        _pendingSuggestions = existingSuggestions;
      } else {
        // Generate new suggestions from incomplete tasks
        await _generateNewSuggestions(today);
      }

      _hasCheckedToday = true;
    } catch (e) {
      _errorMessage = 'Failed to check for rollover suggestions: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force regenerate suggestions (for testing or manual refresh)
  Future<void> regenerateSuggestions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final today = _normalizeDate(DateTime.now());
      await _generateNewSuggestions(today);
    } catch (e) {
      _errorMessage = 'Failed to regenerate suggestions: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate new suggestions from incomplete tasks
  Future<void> _generateNewSuggestions(DateTime forDate) async {
    // Get all tasks (we need to check across all dates for incomplete ones)
    final allTasks = _storageService.getAllSignalTasks();

    // Generate suggestions for incomplete tasks before today
    final suggestions = _rolloverService.generateSuggestions(
      tasks: allTasks,
      forDate: forDate,
    );

    // Save suggestions to storage
    for (final suggestion in suggestions) {
      await _storageService.addRolloverSuggestion(suggestion);
    }

    _pendingSuggestions = suggestions;
  }

  // ============ Processing Suggestions ============

  /// Accept a suggestion and create a new task
  ///
  /// Returns the created SignalTask
  Future<SignalTask> acceptSuggestion(RolloverSuggestion suggestion) async {
    // Create the new task
    final newTask = _rolloverService.createTaskFromSuggestion(
      suggestion: suggestion,
      scheduledDate: suggestion.suggestedForDate,
    );

    // Update the suggestion with accepted status and new task ID
    suggestion.accept(createdTaskId: newTask.id);
    await _storageService.updateRolloverSuggestion(suggestion);

    // Mark the original task as rolled
    await _markOriginalTaskAsRolled(suggestion.originalTaskId);

    // Save the new task
    await _storageService.addSignalTask(newTask);

    // Remove from pending list
    _pendingSuggestions.removeWhere((s) => s.id == suggestion.id);
    notifyListeners();

    return newTask;
  }

  /// Accept a suggestion with modified time
  ///
  /// Returns the created SignalTask
  Future<SignalTask> acceptWithModification(
    RolloverSuggestion suggestion,
    int newMinutes,
  ) async {
    // Update the suggestion with modified time
    suggestion.acceptWithModification(newMinutes);

    // Create the new task (will use finalMinutes which includes modification)
    final newTask = _rolloverService.createTaskFromSuggestion(
      suggestion: suggestion,
      scheduledDate: suggestion.suggestedForDate,
    );

    // Update the suggestion with the new task ID
    suggestion.createdTaskId = newTask.id;
    await _storageService.updateRolloverSuggestion(suggestion);

    // Mark the original task as rolled
    await _markOriginalTaskAsRolled(suggestion.originalTaskId);

    // Save the new task
    await _storageService.addSignalTask(newTask);

    // Remove from pending list
    _pendingSuggestions.removeWhere((s) => s.id == suggestion.id);
    notifyListeners();

    return newTask;
  }

  /// Dismiss a suggestion (user forgot to mark complete, or doesn't want to continue)
  Future<void> dismissSuggestion(RolloverSuggestion suggestion) async {
    suggestion.dismiss();
    await _storageService.updateRolloverSuggestion(suggestion);

    // Optionally mark original as rolled to prevent future suggestions
    // This depends on whether we want dismissed tasks to reappear
    // For now, we mark them as rolled so they don't come back
    await _markOriginalTaskAsRolled(suggestion.originalTaskId);

    // Remove from pending list
    _pendingSuggestions.removeWhere((s) => s.id == suggestion.id);
    notifyListeners();
  }

  /// Accept all pending suggestions
  Future<List<SignalTask>> acceptAllSuggestions() async {
    final createdTasks = <SignalTask>[];

    // Create a copy of the list since we're modifying it
    final suggestionsToAccept = List<RolloverSuggestion>.from(
      _pendingSuggestions,
    );

    for (final suggestion in suggestionsToAccept) {
      final task = await acceptSuggestion(suggestion);
      createdTasks.add(task);
    }

    return createdTasks;
  }

  /// Dismiss all pending suggestions
  Future<void> dismissAllSuggestions() async {
    // Create a copy of the list since we're modifying it
    final suggestionsToDismiss = List<RolloverSuggestion>.from(
      _pendingSuggestions,
    );

    for (final suggestion in suggestionsToDismiss) {
      await dismissSuggestion(suggestion);
    }
  }

  // ============ Helpers ============

  /// Mark the original task as rolled to prevent duplicate suggestions
  Future<void> _markOriginalTaskAsRolled(String taskId) async {
    final task = _storageService.getSignalTask(taskId);
    if (task != null && task.status != TaskStatus.rolled) {
      task.markRolled();
      await _storageService.updateSignalTask(task);
    }
  }

  /// Normalize date to midnight
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Reset the checked status (for testing or new day)
  void resetCheckedStatus() {
    _hasCheckedToday = false;
    notifyListeners();
  }

  /// Clear all state (for testing)
  void clear() {
    _pendingSuggestions = [];
    _hasCheckedToday = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
