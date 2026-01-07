// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_slot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimeSlotAdapter extends TypeAdapter<TimeSlot> {
  @override
  final int typeId = 12;

  @override
  TimeSlot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeSlot(
      id: fields[0] as String,
      plannedStartTime: fields[1] as DateTime,
      plannedEndTime: fields[2] as DateTime,
      actualStartTime: fields[3] as DateTime?,
      actualEndTime: fields[4] as DateTime?,
      isActive: fields[5] as bool,
      autoEnd: fields[6] as bool,
      linkedSubTaskIds: (fields[7] as List?)?.cast<String>(),
      googleCalendarEventId: fields[8] as String?,
      wasManualContinue: fields[9] as bool,
      accumulatedSeconds: fields[10] as int,
      externalCalendarEventId: fields[11] as String?,
      sessionStartTime: fields[12] as DateTime?,
      lastStopTime: fields[13] as DateTime?,
      hasSyncedToCalendar: fields[14] as bool,
      isDiscarded: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TimeSlot obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.plannedStartTime)
      ..writeByte(2)
      ..write(obj.plannedEndTime)
      ..writeByte(3)
      ..write(obj.actualStartTime)
      ..writeByte(4)
      ..write(obj.actualEndTime)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.autoEnd)
      ..writeByte(7)
      ..write(obj.linkedSubTaskIds)
      ..writeByte(8)
      ..write(obj.googleCalendarEventId)
      ..writeByte(9)
      ..write(obj.wasManualContinue)
      ..writeByte(10)
      ..write(obj.accumulatedSeconds)
      ..writeByte(11)
      ..write(obj.externalCalendarEventId)
      ..writeByte(12)
      ..write(obj.sessionStartTime)
      ..writeByte(13)
      ..write(obj.lastStopTime)
      ..writeByte(14)
      ..write(obj.hasSyncedToCalendar)
      ..writeByte(15)
      ..write(obj.isDiscarded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
