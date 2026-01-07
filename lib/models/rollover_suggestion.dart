import 'package:hive/hive.dart';

part 'rollover_suggestion.g.dart';

/// Status of a rollover suggestion
@HiveType(typeId: 20)
enum SuggestionStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  accepted,
  @HiveField(2)
  modified, // User accepted but changed the time
  @HiveField(3)
  dismissed,
}

/// A suggestion to roll over an incomplete task to the next day
@HiveType(typeId: 21)
class RolloverSuggestion extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String originalTaskId;

  @HiveField(2)
  String originalTaskTitle;

  @HiveField(3)
  int suggestedMinutes; // Remaining time to complete

  @HiveField(4)
  List<String> tagIds;

  @HiveField(5)
  DateTime suggestedForDate; // The date to roll over to

  @HiveField(6)
  SuggestionStatus status;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  String? createdTaskId; // ID of task created from this suggestion (if accepted)

  @HiveField(9)
  int? modifiedMinutes; // If user modified the suggested time

  RolloverSuggestion({
    required this.id,
    required this.originalTaskId,
    required this.originalTaskTitle,
    required this.suggestedMinutes,
    List<String>? tagIds,
    required this.suggestedForDate,
    this.status = SuggestionStatus.pending,
    required this.createdAt,
    this.createdTaskId,
    this.modifiedMinutes,
  }) : tagIds = tagIds ?? [];

  /// Format suggested time as readable string
  String get formattedSuggestedTime => _formatMinutes(suggestedMinutes);

  /// Format modified time as readable string (if modified)
  String? get formattedModifiedTime {
    if (modifiedMinutes == null) return null;
    return _formatMinutes(modifiedMinutes!);
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  /// Accept this suggestion
  void accept({String? createdTaskId}) {
    status = SuggestionStatus.accepted;
    this.createdTaskId = createdTaskId;
  }

  /// Accept with modification
  void acceptWithModification(int newMinutes, {String? createdTaskId}) {
    status = SuggestionStatus.modified;
    modifiedMinutes = newMinutes;
    this.createdTaskId = createdTaskId;
  }

  /// Dismiss this suggestion
  void dismiss() {
    status = SuggestionStatus.dismissed;
  }

  /// Whether this suggestion is still pending
  bool get isPending => status == SuggestionStatus.pending;

  /// The final minutes (modified if applicable, otherwise suggested)
  int get finalMinutes => modifiedMinutes ?? suggestedMinutes;

  /// Create a copy with optional overrides
  RolloverSuggestion copyWith({
    String? id,
    String? originalTaskId,
    String? originalTaskTitle,
    int? suggestedMinutes,
    List<String>? tagIds,
    DateTime? suggestedForDate,
    SuggestionStatus? status,
    DateTime? createdAt,
    String? createdTaskId,
    int? modifiedMinutes,
  }) {
    return RolloverSuggestion(
      id: id ?? this.id,
      originalTaskId: originalTaskId ?? this.originalTaskId,
      originalTaskTitle: originalTaskTitle ?? this.originalTaskTitle,
      suggestedMinutes: suggestedMinutes ?? this.suggestedMinutes,
      tagIds: tagIds ?? List.from(this.tagIds),
      suggestedForDate: suggestedForDate ?? this.suggestedForDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdTaskId: createdTaskId ?? this.createdTaskId,
      modifiedMinutes: modifiedMinutes ?? this.modifiedMinutes,
    );
  }
}
