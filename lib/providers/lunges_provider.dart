import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum LungesState { standing, goingDown, atBottom, comingUp }

class LungesProvider extends ChangeNotifier {
  LungesState _currentState = LungesState.standing;
  int _repCount = 0;
  String _status = "Siap... Lakukan lunges.";
  double _frontKneeAngle = 0.0;
  bool _hasStarted = false;
  
  bool _leftDone = false;
  bool _rightDone = false;

  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  DateTime? _phaseStartTime;
  final List<Offset> _trajectoryPoints = [];

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get kneeAngle => _frontKneeAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = LungesState.standing;
    _repCount = 0;
    _status = "Siap... Lakukan lunges.";
    _frontKneeAngle = 0.0;
    _hasStarted = false;
    _leftDone = false;
    _rightDone = false;
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
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    if (leftHip != null) {
      _trajectoryPoints.add(Offset(leftHip.x, leftHip.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    if (leftShoulder == null || leftHip == null || rightHip == null || 
        leftKnee == null || rightKnee == null || leftAnkle == null || rightAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold || leftHip.likelihood < threshold || 
        rightHip.likelihood < threshold || leftKnee.likelihood < threshold || 
        rightKnee.likelihood < threshold || leftAnkle.likelihood < threshold || rightAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Tentukan kaki mana yang di depan (lutut depan lebih tinggi / y lebih kecil, karena lutut belakang hampir menyentuh lantai)
    bool isLeftForward = leftKnee.y < rightKnee.y;

    final frontHip = isLeftForward ? leftHip : rightHip;
    final frontKnee = isLeftForward ? leftKnee : rightKnee;
    final frontAnkle = isLeftForward ? leftAnkle : rightAnkle;

    final angle = _calculateAngle(frontHip, frontKnee, frontAnkle);
    _frontKneeAngle = angle;

    const maxAngle = 160.0; // Berdiri
    const minAngle = 110.0; // Turun (sekitar 90 derajat, tapi di sensor bisa 110)

    if (maxAngle - minAngle > 0) {
      double rom = ((maxAngle - angle) / (maxAngle - minAngle)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    _analyzeLungesState(angle, minAngle, maxAngle, isLeftForward);
    notifyListeners();
  }

  void _analyzeLungesState(double angle, double minAngle, double maxAngle, bool isLeftForward) {
    switch (_currentState) {
      case LungesState.standing:
        if (angle < maxAngle - 10) {
          _hasStarted = true;
          _currentState = LungesState.goingDown;
          _status = "Turun...";
          _isGoodPosture = false;
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        } else {
          String pending = "";
          if (_leftDone && !_rightDone) pending = "Kiri Selesai. Lakukan Kanan!";
          if (!_leftDone && _rightDone) pending = "Kanan Selesai. Lakukan Kiri!";
          if (pending.isNotEmpty) {
            _status = pending;
          }
        }
        break;

      case LungesState.goingDown:
        if (angle <= minAngle) {
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 800) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

          _currentState = LungesState.atBottom;
          _status = "Posisi Bagus! Naik!";
          _isGoodPosture = true;
        } else if (angle > maxAngle) {
          _currentState = LungesState.standing;
          _status = "Berdiri Tegak";
          _isGoodPosture = false;
        }
        break;

      case LungesState.atBottom:
        if (angle > minAngle + 15) {
          _currentState = LungesState.comingUp;
          _status = "Naik...";
          _phaseStartTime = DateTime.now();
          
          // Catat gerakan kaki ini selesai
          if (isLeftForward) {
            _leftDone = true;
          } else {
            _rightDone = true;
          }
        }
        break;

      case LungesState.comingUp:
        if (angle > maxAngle - 10) {
          _currentState = LungesState.standing;
          
          if (_leftDone && _rightDone) {
            _repCount++;
            _status = "REPETISI KE-$_repCount (GOOD!)";
            _leftDone = false;
            _rightDone = false;
            _isGoodPosture = true;
          } else {
            if (_leftDone) {
              _status = "Lunges kiri selesai, ganti kaki!";
            } else if (_rightDone) {
              _status = "Lunges kanan selesai, ganti kaki!";
            }
            _isGoodPosture = true;
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
