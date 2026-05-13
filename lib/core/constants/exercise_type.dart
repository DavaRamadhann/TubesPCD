import 'package:flutter/material.dart';

enum ExerciseType {
  squat,
  sitUp,
  pushUp,
}

extension ExerciseTypeExtension on ExerciseType {
  String get label {
    switch (this) {
      case ExerciseType.squat:
        return 'Squat';
      case ExerciseType.sitUp:
        return 'Sit-Up';
      case ExerciseType.pushUp:
        return 'Push-Up';
    }
  }

  IconData get icon {
    switch (this) {
      case ExerciseType.squat:
        return Icons.fitness_center;
      case ExerciseType.sitUp:
        return Icons.airline_seat_recline_normal;
      case ExerciseType.pushUp:
        return Icons.sports_gymnastics;
    }
  }

  String get angleLabel {
    switch (this) {
      case ExerciseType.squat:
        return 'Sudut Lutut';
      case ExerciseType.sitUp:
        return 'Sudut Badan';
      case ExerciseType.pushUp:
        return 'Sudut Siku';
    }
  }
}
