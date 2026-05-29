// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgramSessionAdapter extends TypeAdapter<ProgramSession> {
  @override
  final int typeId = 1;

  @override
  ProgramSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramSession(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      name: fields[2] as String,
      totalDurationSeconds: fields[3] as int,
      exercises: (fields[4] as List).cast<ProgramExerciseResult>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProgramSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.totalDurationSeconds)
      ..writeByte(4)
      ..write(obj.exercises);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgramExerciseResultAdapter extends TypeAdapter<ProgramExerciseResult> {
  @override
  final int typeId = 2;

  @override
  ProgramExerciseResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramExerciseResult(
      exerciseType: fields[0] as String,
      totalReps: fields[1] as int,
      targetReps: fields[2] as int,
      targetSets: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramExerciseResult obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.exerciseType)
      ..writeByte(1)
      ..write(obj.totalReps)
      ..writeByte(2)
      ..write(obj.targetReps)
      ..writeByte(3)
      ..write(obj.targetSets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramExerciseResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
