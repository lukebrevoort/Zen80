// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StreakDataAdapter extends TypeAdapter<StreakData> {
  @override
  final int typeId = 22;

  @override
  StreakData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StreakData(
      currentStreak: fields[0] as int,
      longestStreak: fields[1] as int,
      lastGoalDate: fields[2] as DateTime?,
      lastProcessedDate: fields[3] as DateTime?,
      pendingMissedDate: fields[5] as DateTime?,
      pendingStreakBase: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StreakData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.currentStreak)
      ..writeByte(1)
      ..write(obj.longestStreak)
      ..writeByte(2)
      ..write(obj.lastGoalDate)
      ..writeByte(3)
      ..write(obj.lastProcessedDate)
      ..writeByte(5)
      ..write(obj.pendingMissedDate)
      ..writeByte(6)
      ..write(obj.pendingStreakBase);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
