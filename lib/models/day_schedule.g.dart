// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DayScheduleAdapter extends TypeAdapter<DaySchedule> {
  @override
  final int typeId = 13;

  @override
  DaySchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // Null-safe casts with sensible defaults for legacy/corrupted data.
    // Also sanitize hour values: legacy data used 24 for "end of day".
    final rawEndHour = (fields[3] as int?) ?? 17;
    return DaySchedule(
      dayOfWeek: (fields[0] as int?) ?? 1,
      activeStartHour: ((fields[1] as int?) ?? 9).clamp(0, 23),
      activeStartMinute: ((fields[2] as int?) ?? 0).clamp(0, 59),
      activeEndHour: rawEndHour == 24 ? 23 : rawEndHour.clamp(0, 23),
      activeEndMinute: ((fields[4] as int?) ?? 0).clamp(0, 59),
      isActiveDay: (fields[5] as bool?) ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, DaySchedule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.dayOfWeek)
      ..writeByte(1)
      ..write(obj.activeStartHour)
      ..writeByte(2)
      ..write(obj.activeStartMinute)
      ..writeByte(3)
      ..write(obj.activeEndHour)
      ..writeByte(4)
      ..write(obj.activeEndMinute)
      ..writeByte(5)
      ..write(obj.isActiveDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
