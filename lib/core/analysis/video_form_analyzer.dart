import '../../providers/pushup_provider.dart';
import '../../providers/squat_provider.dart';
import '../../providers/situp_provider.dart';
import '../../providers/shouldertap_provider.dart';
import '../../providers/lunges_provider.dart';
import '../../providers/burpees_provider.dart';
import '../../providers/jumpingjack_provider.dart';
import '../../providers/benchdips_provider.dart';
import '../../providers/plank_provider.dart';
import '../../providers/legraise_provider.dart';
import '../../services/pose_inference_service.dart';
import '../constants/exercise_type.dart';

class VideoAnalysisResult {
  final int totalReps;
  final double maxRom;
  final int totalFrames;
  final int badPostureFrames;
  final int score;
  final String feedback;

  VideoAnalysisResult({
    required this.totalReps,
    required this.maxRom,
    required this.totalFrames,
    required this.badPostureFrames,
    required this.score,
    required this.feedback,
  });
}

class VideoFormAnalyzer {
  final PoseInferenceService _poseService;

  VideoFormAnalyzer(this._poseService);

  dynamic _getProviderForExercise(ExerciseType type) {
    switch (type) {
      case ExerciseType.squat: return SquatProvider();
      case ExerciseType.sitUp: return SitUpProvider();
      case ExerciseType.pushUp: return PushUpProvider();
      case ExerciseType.shoulderTap: return ShoulderTapProvider();
      case ExerciseType.lunges: return LungesProvider();
      case ExerciseType.burpees: return BurpeesProvider();
      case ExerciseType.jumpingJack: return JumpingJackProvider();
      case ExerciseType.benchDips: return BenchDipsProvider();
      case ExerciseType.plank: return PlankProvider();
      case ExerciseType.legRaise: return LegRaiseProvider();
    }
  }

  Future<VideoAnalysisResult> analyzeFrames(List<String> framePaths, ExerciseType exerciseType) async {
    dynamic provider = _getProviderForExercise(exerciseType);
    int badPostureFrames = 0;
    double maxRomValue = 0.0;

    for (String path in framePaths) {
      final inferenceResult = await _poseService.processStaticImage(path);
      if (inferenceResult != null && inferenceResult.poses.isNotEmpty) {
        // Feed the first pose to the provider for analysis
        provider.processPose(inferenceResult.poses.first);
        
        // Track bad posture only after the exercise has officially started
        if (provider.hasStarted && !provider.isGoodPosture) {
          badPostureFrames++;
        }
        
        // Track Max ROM
        if (provider.hasStarted && provider.romPercentage > maxRomValue) {
          maxRomValue = provider.romPercentage;
        }
      }
    }

    final reps = provider.repCount;
    final maxRom = maxRomValue;
    final totalFrames = framePaths.length;
    
    // Calculate Score (0-100)
    double postureScore = 50.0;
    if (totalFrames > 0 && provider.hasStarted) {
       double badRatio = badPostureFrames / totalFrames;
       // Toleransi: Anggap 30% bad posture adalah wajar (karena transisi turun/naik atau noise ML)
       // Penalti hanya berlaku jika badRatio > 0.3
       double effectiveBadRatio = (badRatio - 0.3).clamp(0.0, 1.0) * 1.5; 
       postureScore = (1.0 - effectiveBadRatio).clamp(0.0, 1.0) * 50.0;
    }

    // Normalisasi ROM: Seringkali di kamera 2D sulit mencapai ROM 100% karena perspektif.
    // Kita anggap ROM 80% sebagai gerakan yang sudah sangat maksimal (dapat nilai penuh 50).
    double romScore = (maxRom / 80.0).clamp(0.0, 1.0) * 50.0;
    
    int totalScore = (postureScore + romScore).round();
    
    // Penalty for not completing any reps despite starting
    if (reps == 0 && provider.hasStarted) {
       totalScore = (totalScore * 0.8).round(); // Penalti lebih ringan (dari 0.5 ke 0.8) karena sering false negative rep
    } else if (!provider.hasStarted) {
       totalScore = 0;
    }

    // Generate string feedback
    String feedback = "";
    if (!provider.hasStarted) {
      feedback = "Tidak terdeteksi gerakan ${exerciseType.label} dalam video.";
    } else if (totalScore >= 85) {
      feedback = "Bagus sekali! Form gerakanmu sangat solid.";
    } else if (totalScore >= 60) {
      if (romScore < 25) {
        feedback = "Cukup baik, tapi pastikan kamu melakukan ${exerciseType.label} dengan lebih dalam (ROM kurang).";
      } else {
        feedback = "Cukup baik, tapi perhatikan postur tubuhmu (terdeteksi form yang kurang tepat).";
      }
    } else {
      feedback = "Form perlu diperbaiki. Pastikan postur tubuh sesuai standar dan maksimalkan rentang gerakan.";
    }

    return VideoAnalysisResult(
      totalReps: reps,
      maxRom: maxRom,
      totalFrames: totalFrames,
      badPostureFrames: badPostureFrames,
      score: totalScore,
      feedback: feedback,
    );
  }
}
