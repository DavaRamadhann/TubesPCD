import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum SitUpState { lyingDown, goingUp, atTop, goingDown }

class SitUpProvider extends ChangeNotifier {
  SitUpState _currentState = SitUpState.lyingDown;
  int _repCount = 0;
  String _status = "Siap... Posisi rebahan.";
  double _bodyAngle = 0.0;   // Sudut torso dari horizontal (0°=rebahan, 90°=tegak)
  double _kneeAngle = 0.0;   // Sudut lutut (hip-knee-ankle)
  bool _isValidRep = false;
  bool _hasStarted = false;

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get bodyAngle => _bodyAngle;
  double get kneeAngle => _kneeAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;

  void reset() {
    _currentState = SitUpState.lyingDown;
    _repCount = 0;
    _status = "Siap... Posisi rebahan.";
    _bodyAngle = 0.0;
    _kneeAngle = 0.0;
    _isValidRep = false;
    _hasStarted = false;
    _currentPose = null;
    _isGoodPosture = false;
    notifyListeners();
  }

  void processPose(Pose pose) {
    _currentPose = pose;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // --- Validasi landmark ---
    if (leftShoulder == null || leftHip == null || leftKnee == null || leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold ||
        leftHip.likelihood < threshold ||
        leftKnee.likelihood < threshold ||
        leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // =============================================
    // VALIDASI POSISI SIT-UP
    // =============================================

    // CHECK 1: Sudut lutut (hip-knee-ankle) — harus ditekuk, maksimal 130°
    final kneeAng = _calculateAngle(leftHip, leftKnee, leftAnkle);
    _kneeAngle = kneeAng;
    if (kneeAng > 130.0) {
      _status = "Tekuk lutut Anda! (${kneeAng.toStringAsFixed(0)}°)";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // CHECK 2: Cegah posisi berdiri — tubuh tidak boleh full vertikal
    final totalVertical = (leftAnkle.y - leftShoulder.y).abs();
    final totalHorizontal = (leftAnkle.x - leftShoulder.x).abs();
    final shoulderToHipVertical = (leftHip.y - leftShoulder.y).abs();
    final hipToAnkleVertical = (leftAnkle.y - leftHip.y).abs();

    if (totalVertical > totalHorizontal * 2.0 && shoulderToHipVertical > hipToAnkleVertical) {
      _status = "Berbaringlah untuk sit-up!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // =============================================
    // SUDUT TORSO DARI HORIZONTAL
    // =============================================
    // Mengukur sudut garis shoulder→hip terhadap garis horizontal
    // INI TIDAK DIPENGARUHI OLEH POSISI LUTUT/ANKLE
    //
    // Rebahan   : shoulder.y ≈ hip.y → sudut ≈ 0° (horizontal)
    // Sit-up    : shoulder.y << hip.y → sudut ≈ 50-80° (naik)
    // Tegak     : sudut ≈ 90°
    final torsoAngle = _calculateTorsoFromHorizontal(leftShoulder, leftHip);
    _bodyAngle = torsoAngle;

    _analyzeSitUpState(torsoAngle);
    notifyListeners();
  }

  /// Menghitung sudut torso dari garis horizontal
  /// 0° = rebahan sempurna, 90° = duduk tegak
  double _calculateTorsoFromHorizontal(PoseLandmark shoulder, PoseLandmark hip) {
    final dx = (hip.x - shoulder.x).abs();  // jarak horizontal
    final dy = (hip.y - shoulder.y).abs();  // jarak vertikal
    // atan2(vertikal, horizontal) → 0° saat rebahan, 90° saat tegak
    final radians = math.atan2(dy, dx);
    return radians * 180 / math.pi;
  }

  void _analyzeSitUpState(double torsoAngle) {
    // Thresholds berdasarkan sudut torso dari horizontal
    const double lyingThreshold = 25.0;   // Di bawah 25° = rebahan
    const double sitUpThreshold = 55.0;   // Di atas 55° = posisi sit-up valid

    switch (_currentState) {
      case SitUpState.lyingDown:
        if (torsoAngle < lyingThreshold) {
          _status = "Posisi rebahan OK. Mulai naik!";
          _isGoodPosture = true;
        }
        if (torsoAngle > lyingThreshold) {
          _hasStarted = true;
          _currentState = SitUpState.goingUp;
          _isValidRep = false;
          _status = "Naik...";
          _isGoodPosture = false;
        }
        break;

      case SitUpState.goingUp:
        if (torsoAngle >= sitUpThreshold) {
          _currentState = SitUpState.atTop;
          _isValidRep = true;
          _status = "Posisi Bagus!";
          _isGoodPosture = true;
        } else if (torsoAngle < lyingThreshold - 5) {
          // Kembali ke posisi rebahan tanpa sampai atas
          _currentState = SitUpState.lyingDown;
          _status = "Naikkan badan lebih tinggi!";
          _isGoodPosture = false;
        }
        break;

      case SitUpState.atTop:
        if (torsoAngle < sitUpThreshold - 10) {
          _currentState = SitUpState.goingDown;
          _status = "Turun...";
        }
        break;

      case SitUpState.goingDown:
        if (torsoAngle < lyingThreshold) {
          _currentState = SitUpState.lyingDown;

          if (_isValidRep) {
            _repCount++;
            _status = "REPETISI KE-$_repCount (GOOD!)";
            _isGoodPosture = true;
          } else {
            _status = "Gerakan kurang sempurna";
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
