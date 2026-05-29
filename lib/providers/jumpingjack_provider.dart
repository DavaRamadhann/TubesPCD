import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum JumpingJackState { standing, goingUp, atTop, comingDown }

class JumpingJackProvider extends ChangeNotifier {
  JumpingJackState _currentState = JumpingJackState.standing;
  int _repCount = 0;
  String _status = "Siap... Berdiri tegak.";
  double _armAngle = 0.0;
  bool _hasStarted = false;

  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  DateTime? _phaseStartTime;
  final List<Offset> _trajectoryPoints = [];

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get armAngle => _armAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = JumpingJackState.standing;
    _repCount = 0;
    _status = "Siap... Berdiri tegak.";
    _armAngle = 0.0;
    _hasStarted = false;
    _currentPose = null;
    _isGoodPosture = false;
    _romPercentage = 0.0;
    _tempoStatus = "";
    _phaseStartTime = null;
    _trajectoryPoints.clear();
    notifyListeners();
  }

  void processPose(Pose pose) {
    _currentPose = pose;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    if (leftShoulder != null) {
      _trajectoryPoints.add(Offset(leftShoulder.x, leftShoulder.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    if (leftShoulder == null || rightShoulder == null || leftHip == null ||
        rightHip == null || leftWrist == null || rightWrist == null ||
        leftAnkle == null || rightAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold || rightShoulder.likelihood < threshold ||
        leftHip.likelihood < threshold || rightHip.likelihood < threshold ||
        leftWrist.likelihood < threshold || rightWrist.likelihood < threshold ||
        leftAnkle.likelihood < threshold || rightAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Anti-cheat: pastikan user berdiri (torso tidak terlalu horizontal)
    final torsoAngle = _calculateTorsoAngle(leftHip, rightHip, rightShoulder);
    if (torsoAngle < 45.0 || torsoAngle > 135.0) {
      _status = "Berdiri tegak!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Hitung sudut lengan rata-rata (kiri + kanan) terhadap vertikal
    final leftArmAngle = _calculateArmAngle(leftShoulder, leftWrist, leftHip);
    final rightArmAngle = _calculateArmAngle(rightShoulder, rightWrist, rightHip);
    final avgArmAngle = (leftArmAngle + rightArmAngle) / 2;
    _armAngle = avgArmAngle;

    // Hitung spread kaki (rasio jarak ankle / lebar bahu)
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    final ankleDistance = (rightAnkle.x - leftAnkle.x).abs();
    final legSpreadRatio = shoulderWidth > 0 ? ankleDistance / shoulderWidth : 0.0;

    const minAngle = 40.0;
    const maxAngle = 140.0;

    if (maxAngle - minAngle > 0) {
      double rom = ((avgArmAngle - minAngle) / (maxAngle - minAngle)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    _analyzeState(avgArmAngle, legSpreadRatio, minAngle, maxAngle);
    notifyListeners();
  }

  void _analyzeState(double armAngle, double legSpreadRatio, double minAngle, double maxAngle) {
    switch (_currentState) {
      case JumpingJackState.standing:
        if (armAngle > minAngle + 10) {
          _hasStarted = true;
          _currentState = JumpingJackState.goingUp;
          _status = "Angkat Tangan!";
          _isGoodPosture = false;
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        } else {
          _status = "Siap... Berdiri tegak.";
          _isGoodPosture = true;
        }
        break;

      case JumpingJackState.goingUp:
        if (armAngle >= maxAngle && legSpreadRatio >= 0.8) {
          _tempoStatus = "";

          _currentState = JumpingJackState.atTop;
          _status = "Posisi Bagus! Turunkan!";
          _isGoodPosture = true;
        } else if (armAngle < minAngle) {
          _currentState = JumpingJackState.standing;
          _status = "Angkat tangan lebih tinggi!";
          _isGoodPosture = false;
        } else if (legSpreadRatio < 0.8) {
          _status = "Buka kaki lebih lebar!";
          _isGoodPosture = false;
        }
        break;

      case JumpingJackState.atTop:
        if (armAngle < maxAngle - 20) {
          _currentState = JumpingJackState.comingDown;
          _status = "Turunkan Tangan...";
          _phaseStartTime = DateTime.now();
        }
        break;

      case JumpingJackState.comingDown:
        if (armAngle <= minAngle + 10) {
          _currentState = JumpingJackState.standing;
          _repCount++;
          _status = "REPETISI KE-$_repCount (GOOD!)";
          _isGoodPosture = true;
        }
        break;
    }
  }

  double _calculateTorsoAngle(PoseLandmark leftHip, PoseLandmark rightHip, PoseLandmark rightShoulder) {
    final hipMidX = (leftHip.x + rightHip.x) / 2;
    final hipMidY = (leftHip.y + rightHip.y) / 2;
    final dx = (rightShoulder.x - hipMidX).abs();
    final dy = (rightShoulder.y - hipMidY).abs();
    final radians = math.atan2(dy, dx);
    return radians * 180 / math.pi;
  }

  double _calculateArmAngle(PoseLandmark shoulder, PoseLandmark wrist, PoseLandmark hip) {
    // Sudut antara vektor shoulder->wrist dan shoulder->hip (vertikal tubuh)
    final armDx = wrist.x - shoulder.x;
    final armDy = wrist.y - shoulder.y;
    final bodyDx = hip.x - shoulder.x;
    final bodyDy = hip.y - shoulder.y;

    final dot = armDx * bodyDx + armDy * bodyDy;
    final armMag = math.sqrt(armDx * armDx + armDy * armDy);
    final bodyMag = math.sqrt(bodyDx * bodyDx + bodyDy * bodyDy);

    if (armMag == 0 || bodyMag == 0) return 0.0;

    final cosAngle = (dot / (armMag * bodyMag)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * 180 / math.pi;
  }
}
