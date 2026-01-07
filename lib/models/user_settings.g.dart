// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 16;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      weeklySchedule: (fields[0] as Map?)?.cast<int, DaySchedule>(),
      autoStartTasks: fields[1] as bool,
      autoEndTasks: fields[2] as bool,
      notificationBeforeEndMinutes: fields[3] as int,
      hasCompletedOnboarding: fields[4] as bool,
      defaultSignalColorHex: fields[5] as String,
      notificationBeforeStartMinutes: fields[6] as int,
      showRolloverSuggestions: fields[7] as bool,
      dataVersion: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.weeklySchedule)
      ..writeByte(1)
      ..write(obj.autoStartTasks)
      ..writeByte(2)
      ..write(obj.autoEndTasks)
      ..writeByte(3)
      ..write(obj.notificationBeforeEndMinutes)
      ..writeByte(4)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(5)
      ..write(obj.defaultSignalColorHex)
      ..writeByte(6)
      ..write(obj.notificationBeforeStartMinutes)
      ..writeByte(7)
      ..write(obj.showRolloverSuggestions)
      ..writeByte(8)
      ..write(obj.dataVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
