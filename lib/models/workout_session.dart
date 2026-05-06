import 'package:hive/hive.dart';

class WorkoutSession {
  final String id;
  final DateTime date;
  final int totalReps;
  final int durationSeconds;

  WorkoutSession({
    required this.id,
    required this.date,
    required this.totalReps,
    required this.durationSeconds,
  });
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 0;

  @override
  WorkoutSession read(BinaryReader reader) {
    return WorkoutSession(
      id: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      totalReps: reader.readInt(),
      durationSeconds: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.totalReps);
    writer.writeInt(obj.durationSeconds);
  }
}
