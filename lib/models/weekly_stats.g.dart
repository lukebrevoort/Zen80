// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyStatsAdapter extends TypeAdapter<WeeklyStats> {
  @override
  final int typeId = 17;

  @override
  WeeklyStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyStats(
      weekStartDate: fields[0] as DateTime,
      totalSignalMinutes: fields[1] as int,
      totalFocusMinutes: fields[2] as int,
      completedTasksCount: fields[3] as int,
      tagBreakdown: (fields[4] as Map?)?.cast<String, int>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyStats obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.weekStartDate)
      ..writeByte(1)
      ..write(obj.totalSignalMinutes)
      ..writeByte(2)
      ..write(obj.totalFocusMinutes)
      ..writeByte(3)
      ..write(obj.completedTasksCount)
      ..writeByte(4)
      ..write(obj.tagBreakdown);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
