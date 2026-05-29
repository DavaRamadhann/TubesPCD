import '../core/constants/exercise_type.dart';

class ExerciseConfig {
  final ExerciseType type;
  final int targetReps;
  final int targetSets;
  final int restDuration;

  ExerciseConfig({
    required this.type,
    required this.targetReps,
    required this.targetSets,
    required this.restDuration,
  });
}
