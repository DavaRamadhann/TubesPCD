import 'package:flutter/material.dart';

enum ExerciseType {
  squat,
  sitUp,
  pushUp,
  shoulderTap,
  lunges,
  burpees,
  jumpingJack,
  benchDips,
  plank,
  legRaise,
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
      case ExerciseType.jumpingJack:
        return 'Jumping Jack';
      case ExerciseType.benchDips:
        return 'Bench Dips';
      case ExerciseType.plank:
        return 'Plank';
      case ExerciseType.legRaise:
        return 'Leg Raise';
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
      case ExerciseType.jumpingJack:
        return Icons.accessibility_new;
      case ExerciseType.benchDips:
        return Icons.event_seat;
      case ExerciseType.plank:
        return Icons.sports_gymnastics;
      case ExerciseType.legRaise:
        return Icons.airline_seat_flat_angled;
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
      case ExerciseType.jumpingJack:
        return 'Sudut Lengan';
      case ExerciseType.benchDips:
        return 'Sudut Siku';
      case ExerciseType.plank:
        return 'Sudut Badan';
      case ExerciseType.legRaise:
        return 'Sudut Pinggul';
    }
  }
}
