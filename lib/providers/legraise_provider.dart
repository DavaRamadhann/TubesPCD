import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum LegRaiseState { legsDown, goingUp, atTop, goingDown }

class LegRaiseProvider extends ChangeNotifier {
  LegRaiseState _currentState = LegRaiseState.legsDown;
  int _repCount = 0;
  String _status = "Siap... Rebahan dan luruskan kaki.";
  double _hipAngle = 0.0;
  bool _isValidRep = false;
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
  double get hipAngle => _hipAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = LegRaiseState.legsDown;
    _repCount = 0;
    _status = "Siap... Rebahan dan luruskan kaki.";
    _hipAngle = 0.0;
    _isValidRep = false;
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
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // Trajectory tracking (menggunakan pergelangan kaki)
    if (leftAnkle != null) {
      _trajectoryPoints.add(Offset(leftAnkle.x, leftAnkle.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

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

    // CHECK 1: Posisi rebahan (Shoulder dan Hip relatif sejajar secara vertikal/horizontal tergantung orientasi kamera)
    // Untuk Leg Raise kita asumsikan tubuh rebahan, tapi mendeteksinya cukup dari sudut kaki agar lebih fleksibel
    // Pastikan kaki lurus (sudut lutut)
    final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    if (kneeAngle < 140.0) {
      _status = "Luruskan lutut Anda!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Hitung sudut pinggul (Shoulder - Hip - Ankle)
    // Lurus (bawah) = ~170-180, Diangkat (atas) = ~80-100
    final angle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
    _hipAngle = angle;

    // Kalkulasi ROM (Range of Motion)
    if (170.0 - 90.0 > 0) {
      double rom = ((170.0 - angle) / (170.0 - 90.0)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    _analyzeLegRaiseState(angle);
    notifyListeners();
  }

  void _analyzeLegRaiseState(double angle) {
    const double legsDownAngle = 150.0; // Batas bawah
    const double legsUpAngle = 115.0;   // Batas atas

    switch (_currentState) {
      case LegRaiseState.legsDown:
        if (angle > legsDownAngle) {
          _status = "Posisi OK. Angkat kaki!";
          _isGoodPosture = true;
        }
        if (angle < legsDownAngle) {
          _hasStarted = true;
          _currentState = LegRaiseState.goingUp;
          _isValidRep = false;
          _status = "Naik...";
          _isGoodPosture = false;
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        }
        break;

      case LegRaiseState.goingUp:
        if (angle <= legsUpAngle) {
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 800) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

          _currentState = LegRaiseState.atTop;
          _isValidRep = true;
          _status = "Posisi Bagus! Turunkan perlahan.";
          _isGoodPosture = true;
        } else if (angle > legsDownAngle + 5) {
          _currentState = LegRaiseState.legsDown;
          _status = "Angkat lebih tinggi!";
          _isGoodPosture = false;
        }
        break;

      case LegRaiseState.atTop:
        if (angle > legsUpAngle + 15) {
          _currentState = LegRaiseState.goingDown;
          _status = "Turun...";
          _phaseStartTime = DateTime.now();
        }
        break;

      case LegRaiseState.goingDown:
        if (angle > legsDownAngle) {
          _currentState = LegRaiseState.legsDown;

          if (_isValidRep) {
            _repCount++;
            _status = "REPETISI KE-$_repCount (GOOD!)";
            _isGoodPosture = true;
          } else {
            _status = "Gerakan kurang penuh";
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
