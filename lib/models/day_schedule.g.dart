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
    return DaySchedule(
      dayOfWeek: fields[0] as int,
      activeStartHour: fields[1] as int,
      activeStartMinute: fields[2] as int,
      activeEndHour: fields[3] as int,
      activeEndMinute: fields[4] as int,
      isActiveDay: fields[5] as bool,
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
