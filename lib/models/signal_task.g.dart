// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signal_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SignalTaskAdapter extends TypeAdapter<SignalTask> {
  @override
  final int typeId = 15;

  @override
  SignalTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SignalTask(
      id: fields[0] as String,
      title: fields[1] as String,
      estimatedMinutes: fields[2] as int,
      tagIds: (fields[3] as List?)?.cast<String>(),
      subTasks: (fields[4] as List?)?.cast<SubTask>(),
      status: fields[5] as TaskStatus,
      scheduledDate: fields[6] as DateTime,
      timeSlots: (fields[7] as List?)?.cast<TimeSlot>(),
      googleCalendarEventId: fields[8] as String?,
      isComplete: fields[9] as bool,
      createdAt: fields[10] as DateTime,
      rolledFromTaskId: fields[11] as String?,
      remainingMinutesFromRollover: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SignalTask obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.estimatedMinutes)
      ..writeByte(3)
      ..write(obj.tagIds)
      ..writeByte(4)
      ..write(obj.subTasks)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.scheduledDate)
      ..writeByte(7)
      ..write(obj.timeSlots)
      ..writeByte(8)
      ..write(obj.googleCalendarEventId)
      ..writeByte(9)
      ..write(obj.isComplete)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.rolledFromTaskId)
      ..writeByte(12)
      ..write(obj.remainingMinutesFromRollover);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final int typeId = 14;

  @override
  TaskStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskStatus.notStarted;
      case 1:
        return TaskStatus.inProgress;
      case 2:
        return TaskStatus.completed;
      case 3:
        return TaskStatus.rolled;
      default:
        return TaskStatus.notStarted;
    }
  }

  @override
  void write(BinaryWriter writer, TaskStatus obj) {
    switch (obj) {
      case TaskStatus.notStarted:
        writer.writeByte(0);
        break;
      case TaskStatus.inProgress:
        writer.writeByte(1);
        break;
      case TaskStatus.completed:
        writer.writeByte(2);
        break;
      case TaskStatus.rolled:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
