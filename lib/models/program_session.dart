import 'package:hive/hive.dart';

part 'program_session.g.dart';

@HiveType(typeId: 1)
class ProgramSession {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime date;
  
  @HiveField(2)
  final String name;
  
  @HiveField(3)
  final int totalDurationSeconds;
  
  @HiveField(4)
  final List<ProgramExerciseResult> exercises;

  ProgramSession({
    required this.id,
    required this.date,
    required this.name,
    required this.totalDurationSeconds,
    required this.exercises,
  });
}

@HiveType(typeId: 2)
class ProgramExerciseResult {
  @HiveField(0)
  final String exerciseType;
  
  @HiveField(1)
  final int totalReps;
  
  @HiveField(2)
  final int targetReps;
  
  @HiveField(3)
  final int targetSets;

  ProgramExerciseResult({
    required this.exerciseType,
    required this.totalReps,
    required this.targetReps,
    required this.targetSets,
  });
}
