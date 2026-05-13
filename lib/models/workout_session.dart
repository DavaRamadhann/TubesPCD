import 'package:hive/hive.dart';

class WorkoutSession {
  final String id;
  final DateTime date;
  final int totalReps;
  final int durationSeconds;
  final String exerciseType;

  WorkoutSession({
    required this.id,
    required this.date,
    required this.totalReps,
    required this.durationSeconds,
    this.exerciseType = 'squat',
  });
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 0;

  @override
  WorkoutSession read(BinaryReader reader) {
    final id = reader.readString();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final totalReps = reader.readInt();
    final durationSeconds = reader.readInt();
    
    // Backward compatible — old data tanpa exerciseType
    String exerciseType = 'squat';
    try {
      exerciseType = reader.readString();
    } catch (_) {
      // Data lama tidak punya field ini
    }

    return WorkoutSession(
      id: id,
      date: date,
      totalReps: totalReps,
      durationSeconds: durationSeconds,
      exerciseType: exerciseType,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.totalReps);
    writer.writeInt(obj.durationSeconds);
    writer.writeString(obj.exerciseType);
  }
}
