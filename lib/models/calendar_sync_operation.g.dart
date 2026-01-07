// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_sync_operation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarSyncOperationAdapter extends TypeAdapter<CalendarSyncOperation> {
  @override
  final int typeId = 19;

  @override
  CalendarSyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarSyncOperation(
      id: fields[0] as String,
      type: fields[1] as SyncOperationType,
      taskId: fields[2] as String,
      timeSlotId: fields[3] as String?,
      googleCalendarEventId: fields[4] as String?,
      eventTitle: fields[5] as String?,
      eventStart: fields[6] as DateTime?,
      eventEnd: fields[7] as DateTime?,
      eventColorHex: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      retryCount: fields[10] as int,
      lastError: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarSyncOperation obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.taskId)
      ..writeByte(3)
      ..write(obj.timeSlotId)
      ..writeByte(4)
      ..write(obj.googleCalendarEventId)
      ..writeByte(5)
      ..write(obj.eventTitle)
      ..writeByte(6)
      ..write(obj.eventStart)
      ..writeByte(7)
      ..write(obj.eventEnd)
      ..writeByte(8)
      ..write(obj.eventColorHex)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.retryCount)
      ..writeByte(11)
      ..write(obj.lastError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarSyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOperationTypeAdapter extends TypeAdapter<SyncOperationType> {
  @override
  final int typeId = 18;

  @override
  SyncOperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOperationType.create;
      case 1:
        return SyncOperationType.update;
      case 2:
        return SyncOperationType.delete;
      default:
        return SyncOperationType.create;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOperationType obj) {
    switch (obj) {
      case SyncOperationType.create:
        writer.writeByte(0);
        break;
      case SyncOperationType.update:
        writer.writeByte(1);
        break;
      case SyncOperationType.delete:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
