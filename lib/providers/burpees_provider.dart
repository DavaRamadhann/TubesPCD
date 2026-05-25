import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum BurpeesState { standing, goingToPlank, plank, comingUp }

class BurpeesProvider extends ChangeNotifier {
  BurpeesState _currentState = BurpeesState.standing;
  int _repCount = 0;
  String _status = "Siap... Berdiri tegak.";
  double _torsoAngle = 0.0;
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
  double get torsoAngle => _torsoAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = BurpeesState.standing;
    _repCount = 0;
    _status = "Siap... Berdiri tegak.";
    _torsoAngle = 0.0;
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
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    
    final threshold = EnvConfig.aiConfidenceThreshold;

    if (leftShoulder != null) {
      _trajectoryPoints.add(Offset(leftShoulder.x, leftShoulder.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    if (leftShoulder == null || leftHip == null || leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold || leftHip.likelihood < threshold || leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Kalkulasi sudut torso terhadap garis vertikal (0° = tegak, 90° = horizontal/plank)
    final angle = _calculateTorsoAngle(leftShoulder, leftHip);
    _torsoAngle = angle;

    // Kalkulasi Range of Motion berdasarkan transisi sudut badan
    // Tegak = ~0 derajat, Plank = ~90 derajat
    const minAngle = 15.0;  // Batas berdiri
    const maxAngle = 70.0;  // Batas plank
    
    if (maxAngle - minAngle > 0) {
      double rom = ((angle - minAngle) / (maxAngle - minAngle)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    _analyzeBurpeesState(angle, minAngle, maxAngle);
    notifyListeners();
  }

  void _analyzeBurpeesState(double angle, double minAngle, double maxAngle) {
    switch (_currentState) {
      case BurpeesState.standing:
        if (angle < minAngle) {
          _status = "Siap. Turun ke Plank!";
          _isGoodPosture = true;
        } else if (angle > minAngle + 10) {
          _hasStarted = true;
          _currentState = BurpeesState.goingToPlank;
          _status = "Turun ke Plank...";
          _isGoodPosture = false;
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        }
        break;

      case BurpeesState.goingToPlank:
        if (angle >= maxAngle) {
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 500) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

          _currentState = BurpeesState.plank;
          _status = "Posisi Plank Bagus! Berdiri!";
          _isGoodPosture = true;
        } else if (angle < minAngle) {
          _currentState = BurpeesState.standing;
          _status = "Turun lebih jauh untuk Plank!";
          _isGoodPosture = false;
        }
        break;

      case BurpeesState.plank:
        if (angle < maxAngle - 15) {
          _currentState = BurpeesState.comingUp;
          _status = "Berdiri tegak atau loncat!";
          _phaseStartTime = DateTime.now();
        }
        break;

      case BurpeesState.comingUp:
        if (angle <= minAngle) {
          _currentState = BurpeesState.standing;
          _repCount++;
          _status = "REPETISI KE-$_repCount (GOOD!)";
          _isGoodPosture = true;
        }
        break;
    }
  }

  double _calculateTorsoAngle(PoseLandmark shoulder, PoseLandmark hip) {
    final dx = (hip.x - shoulder.x).abs();
    final dy = (hip.y - shoulder.y).abs();
    final radians = math.atan2(dx, dy);
    return radians * 180 / math.pi;
  }
}
