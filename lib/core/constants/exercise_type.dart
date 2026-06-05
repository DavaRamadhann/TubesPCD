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

  List<Color> get gradientColors {
    switch (this) {
      case ExerciseType.squat:
        return [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)];
      case ExerciseType.sitUp:
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
      case ExerciseType.pushUp:
        return [const Color(0xFFDC2626), const Color(0xFFF87171)];
      case ExerciseType.shoulderTap:
        return [const Color(0xFF059669), const Color(0xFF34D399)];
      case ExerciseType.lunges:
        return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
      case ExerciseType.burpees:
        return [const Color(0xFFBE185D), const Color(0xFFF472B6)];
      case ExerciseType.jumpingJack:
        return [const Color(0xFF0891B2), const Color(0xFF67E8F9)];
      case ExerciseType.benchDips:
        return [const Color(0xFF4338CA), const Color(0xFF818CF8)];
      case ExerciseType.plank:
        return [const Color(0xFFB45309), const Color(0xFFFCD34D)];
      case ExerciseType.legRaise:
        return [const Color(0xFF065F46), const Color(0xFF6EE7B7)];
    }
  }
}
