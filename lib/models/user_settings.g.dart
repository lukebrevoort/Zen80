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
      autoStartTasks: fields[1] as bool? ?? false,
      autoEndTasks: fields[2] as bool? ?? true,
      notificationBeforeEndMinutes: fields[3] as int? ?? 5,
      hasCompletedOnboarding: fields[4] as bool? ?? false,
      defaultSignalColorHex: fields[5] as String? ?? '#2563EB',
      notificationBeforeStartMinutes: fields[6] as int? ?? 5,
      showRolloverSuggestions: fields[7] as bool? ?? true,
      dataVersion: fields[8] as int? ?? 1,
      timezone: fields[9] as String?,
      hasCompletedScheduleSetup: fields[10] as bool? ?? false,
      enableStartReminders: fields[11] as bool? ?? true,
      enableEndReminders: fields[12] as bool? ?? true,
      enableNextTaskReminders: fields[13] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.dataVersion)
      ..writeByte(9)
      ..write(obj.timezone)
      ..writeByte(10)
      ..write(obj.hasCompletedScheduleSetup)
      ..writeByte(11)
      ..write(obj.enableStartReminders)
      ..writeByte(12)
      ..write(obj.enableEndReminders)
      ..writeByte(13)
      ..write(obj.enableNextTaskReminders);
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
