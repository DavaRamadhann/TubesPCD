import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum SquatState { standing, goingDown, atBottom, comingUp }

class SquatProvider extends ChangeNotifier {
  SquatState _currentState = SquatState.standing;
  int _repCount = 0;
  String _status = "Siap...";
  double _kneeAngle = 0.0;
  bool _isValidRep = false;
  double _standingYDistance = 0.0;
  bool _hasStarted = false;
  
  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get kneeAngle => _kneeAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;

  void reset() {
    _currentState = SquatState.standing;
    _repCount = 0;
    _status = "Siap...";
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
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final minAngle = EnvConfig.squatMinAngle;
    final maxAngle = EnvConfig.squatMaxAngle;
    final threshold = EnvConfig.aiConfidenceThreshold;

    if (leftShoulder == null || leftHip == null || leftKnee == null || leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold || leftHip.likelihood < threshold || leftKnee.likelihood < threshold || leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // --- ANTI-TIDURAN / REBAHAN HACK ---
    // 1. Bahu harus di atas pinggul, dan pinggul harus di atas engkel (Y semakin besar ke bawah layar)
    if (leftShoulder.y >= leftHip.y || leftHip.y >= leftAnkle.y) {
       _status = "Berdirilah dengan tegak (Posisi salah)";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    // 2. Pastikan tubuh orang tersebut dominan vertikal, bukan rebahan horizontal di layar
    final verticalBodyLength = (leftAnkle.y - leftShoulder.y).abs();
    final horizontalBodyLength = (leftAnkle.x - leftShoulder.x).abs();
    
    if (verticalBodyLength < horizontalBodyLength * 0.5) {
       _status = "Tolong berdirikan badan Anda!";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    final angle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    _kneeAngle = angle;

    double lowestAnkleY = leftAnkle.y;
    if (rightAnkle != null && rightAnkle.likelihood > threshold) {
      lowestAnkleY = math.max(lowestAnkleY, rightAnkle.y);
    }
    
    // Jarak vertikal pinggul ke lantai (engkel terendah)
    final currentYDistance = lowestAnkleY - leftHip.y;

    _analyzeSquatState(angle, minAngle, maxAngle, currentYDistance);
    notifyListeners();
  }

  void _analyzeSquatState(double angle, double minAngle, double maxAngle, double currentYDistance) {
    switch (_currentState) {
      case SquatState.standing:
        // Update referensi tinggi saat berdiri tegak
        if (angle > maxAngle - 10) {
          _standingYDistance = currentYDistance;
        }

        if (angle < maxAngle) {
          _hasStarted = true; // Gerakan dimulai, siluet akan hilang
          _currentState = SquatState.goingDown;
          _isValidRep = false;
          _status = "Turun...";
          _isGoodPosture = false;
        }
        break;

      case SquatState.goingDown:
        if (angle <= minAngle) {
          // Cek apakah pinggul benar-benar turun relatif terhadap lantai (anti-hack angkat lutut)
          if (currentYDistance < _standingYDistance * 0.75) {
            _currentState = SquatState.atBottom;
            _isValidRep = true; 
            _status = "Posisi Bagus!";
            _isGoodPosture = true;
          } else {
            _status = "Turunkan pinggul! (Jangan angkat lutut)";
            _isGoodPosture = false;
          }
        } else if (angle > maxAngle) {
          _currentState = SquatState.standing;
          _status = "Berdiri Tegak";
          _isGoodPosture = false;
        }
        break;

      case SquatState.atBottom:
        if (angle > minAngle + 15) { 
          _currentState = SquatState.comingUp;
          _status = "Naik...";
        }
        break;

      case SquatState.comingUp:
        if (angle > maxAngle) { 
          _currentState = SquatState.standing;
          
          if (_isValidRep) {
            _repCount++;
            _status = "REPETISI KE-$_repCount (GOOD!)";
            _isGoodPosture = true;
          } else {
            _status = "Gerakan Kurang Dalam";
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
