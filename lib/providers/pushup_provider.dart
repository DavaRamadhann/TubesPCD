import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum PushUpState { armsExtended, goingDown, atBottom, comingUp }

class PushUpProvider extends ChangeNotifier {
  PushUpState _currentState = PushUpState.armsExtended;
  int _repCount = 0;
  String _status = "Siap... Posisi push-up.";
  double _elbowAngle = 0.0;
  bool _isValidRep = false;
  bool _hasStarted = false;

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get elbowAngle => _elbowAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;

  void reset() {
    _currentState = PushUpState.armsExtended;
    _repCount = 0;
    _status = "Siap... Posisi push-up.";
    _elbowAngle = 0.0;
    _isValidRep = false;
    _hasStarted = false;
    _currentPose = null;
    _isGoodPosture = false;
    notifyListeners();
  }

  void processPose(Pose pose) {
    _currentPose = pose;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // --- Validasi landmark ---
    if (leftShoulder == null || leftElbow == null || leftWrist == null ||
        leftHip == null || leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold ||
        leftElbow.likelihood < threshold ||
        leftWrist.likelihood < threshold ||
        leftHip.likelihood < threshold ||
        leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // =============================================
    // VALIDASI POSISI PUSH-UP
    // =============================================

    // CHECK 1: Tubuh harus dalam posisi horizontal/prone
    // Saat push-up, badan harus mendatar — tidak boleh berdiri tegak
    final totalVertical = (leftAnkle.y - leftShoulder.y).abs();
    final totalHorizontal = (leftAnkle.x - leftShoulder.x).abs();

    if (totalVertical > totalHorizontal * 1.5) {
      _status = "Posisi push-up: badan harus mendatar!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // CHECK 2: Body alignment — shoulder, hip, ankle harus relatif lurus
    // Mencegah pinggul terlalu tinggi atau terlalu rendah
    final bodyLineAngle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
    if (bodyLineAngle < 140.0) {
      _status = "Luruskan badan Anda!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // --- Kalkulasi sudut siku (shoulder-elbow-wrist) ---
    // Arms extended (atas): ~150-170°
    // Arms bent (bawah): ~60-90°
    final angle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    _elbowAngle = angle;

    _analyzePushUpState(angle);
    notifyListeners();
  }

  void _analyzePushUpState(double angle) {
    // Push-up thresholds
    const double extendedAngle = 140.0;  // Lengan lurus (posisi atas)
    const double bentAngle = 100.0;       // Lengan ditekuk (posisi bawah)

    switch (_currentState) {
      case PushUpState.armsExtended:
        if (angle > extendedAngle) {
          _status = "Posisi push-up OK. Mulai turun!";
          _isGoodPosture = true;
        }
        if (angle < extendedAngle) {
          _hasStarted = true;
          _currentState = PushUpState.goingDown;
          _isValidRep = false;
          _status = "Turun...";
          _isGoodPosture = false;
        }
        break;

      case PushUpState.goingDown:
        if (angle <= bentAngle) {
          _currentState = PushUpState.atBottom;
          _isValidRep = true;
          _status = "Posisi Bagus! Naik!";
          _isGoodPosture = true;
        } else if (angle > extendedAngle + 5) {
          _currentState = PushUpState.armsExtended;
          _status = "Turun lebih dalam!";
          _isGoodPosture = false;
        }
        break;

      case PushUpState.atBottom:
        if (angle > bentAngle + 15) {
          _currentState = PushUpState.comingUp;
          _status = "Naik...";
        }
        break;

      case PushUpState.comingUp:
        if (angle > extendedAngle) {
          _currentState = PushUpState.armsExtended;

          if (_isValidRep) {
            _repCount++;
            _status = "REPETISI KE-$_repCount (GOOD!)";
            _isGoodPosture = true;
          } else {
            _status = "Gerakan kurang dalam";
            _isGoodPosture = false;
          }
        }
        break;
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = radians * 180 / math.pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }
}
