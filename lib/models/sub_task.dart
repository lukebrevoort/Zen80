import 'package:hive/hive.dart';

part 'sub_task.g.dart';

/// A sub-task (checklist item) that can be linked to specific time slots
/// Sub-tasks help break down larger Signal tasks into manageable pieces
@HiveType(typeId: 11)
class SubTask {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isChecked;

  @HiveField(3)
  List<String> linkedTimeSlotIds; // Which time slots this sub-task is assigned to

  SubTask({
    required this.id,
    required this.title,
    this.isChecked = false,
    List<String>? linkedTimeSlotIds,
  }) : linkedTimeSlotIds = linkedTimeSlotIds ?? [];

  /// Toggle the checked state
  void toggle() {
    isChecked = !isChecked;
  }

  /// Link this sub-task to a time slot
  void linkToTimeSlot(String timeSlotId) {
    if (!linkedTimeSlotIds.contains(timeSlotId)) {
      linkedTimeSlotIds.add(timeSlotId);
    }
  }

  /// Unlink this sub-task from a time slot
  void unlinkFromTimeSlot(String timeSlotId) {
    linkedTimeSlotIds.remove(timeSlotId);
  }

  /// Check if this sub-task is linked to a specific time slot
  bool isLinkedToTimeSlot(String timeSlotId) {
    return linkedTimeSlotIds.contains(timeSlotId);
  }

  /// Create a copy with optional overrides
  SubTask copyWith({
    String? id,
    String? title,
    bool? isChecked,
    List<String>? linkedTimeSlotIds,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
      linkedTimeSlotIds: linkedTimeSlotIds ?? List.from(this.linkedTimeSlotIds),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
