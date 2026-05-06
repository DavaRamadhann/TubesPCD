import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static double get aiConfidenceThreshold => 
      double.tryParse(dotenv.env['AI_CONFIDENCE_THRESHOLD'] ?? '0.6') ?? 0.6;
      
  static double get squatMinAngle => 
      double.tryParse(dotenv.env['SQUAT_MIN_ANGLE'] ?? '95.0') ?? 95.0;
      
  static double get squatMaxAngle => 
      double.tryParse(dotenv.env['SQUAT_MAX_ANGLE'] ?? '160.0') ?? 160.0;
}
