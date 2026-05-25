import 'package:flutter/material.dart';

enum ExerciseType {
  squat,
  sitUp,
  pushUp,
  shoulderTap,
  lunges,
  burpees,
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
      case ExerciseType.shoulderTap:
        return 'Shoulder Tap';
      case ExerciseType.lunges:
        return 'Lunges';
      case ExerciseType.burpees:
        return 'Burpees';
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
      case ExerciseType.shoulderTap:
        return Icons.pan_tool_alt;
      case ExerciseType.lunges:
        return Icons.directions_walk;
      case ExerciseType.burpees:
        return Icons.directions_run;
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
      case ExerciseType.shoulderTap:
        return 'Jarak Ketukan';
      case ExerciseType.lunges:
        return 'Sudut Lutut Depan';
      case ExerciseType.burpees:
        return 'Sudut Badan';
    }
  }
}
