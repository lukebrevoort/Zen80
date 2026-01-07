// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rollover_suggestion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RolloverSuggestionAdapter extends TypeAdapter<RolloverSuggestion> {
  @override
  final int typeId = 21;

  @override
  RolloverSuggestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RolloverSuggestion(
      id: fields[0] as String,
      originalTaskId: fields[1] as String,
      originalTaskTitle: fields[2] as String,
      suggestedMinutes: fields[3] as int,
      tagIds: (fields[4] as List?)?.cast<String>(),
      suggestedForDate: fields[5] as DateTime,
      status: fields[6] as SuggestionStatus,
      createdAt: fields[7] as DateTime,
      createdTaskId: fields[8] as String?,
      modifiedMinutes: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RolloverSuggestion obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originalTaskId)
      ..writeByte(2)
      ..write(obj.originalTaskTitle)
      ..writeByte(3)
      ..write(obj.suggestedMinutes)
      ..writeByte(4)
      ..write(obj.tagIds)
      ..writeByte(5)
      ..write(obj.suggestedForDate)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.createdTaskId)
      ..writeByte(9)
      ..write(obj.modifiedMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RolloverSuggestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SuggestionStatusAdapter extends TypeAdapter<SuggestionStatus> {
  @override
  final int typeId = 20;

  @override
  SuggestionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SuggestionStatus.pending;
      case 1:
        return SuggestionStatus.accepted;
      case 2:
        return SuggestionStatus.modified;
      case 3:
        return SuggestionStatus.dismissed;
      default:
        return SuggestionStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SuggestionStatus obj) {
    switch (obj) {
      case SuggestionStatus.pending:
        writer.writeByte(0);
        break;
      case SuggestionStatus.accepted:
        writer.writeByte(1);
        break;
      case SuggestionStatus.modified:
        writer.writeByte(2);
        break;
      case SuggestionStatus.dismissed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
