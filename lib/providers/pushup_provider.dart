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
  
  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  DateTime? _phaseStartTime;
  final List<Offset> _trajectoryPoints = [];

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get elbowAngle => _elbowAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = PushUpState.armsExtended;
    _repCount = 0;
    _status = "Siap... Posisi push-up.";
    _elbowAngle = 0.0;
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
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // Trajectory tracking (menggunakan bahu)
    if (leftShoulder != null) {
      _trajectoryPoints.add(Offset(leftShoulder.x, leftShoulder.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

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

    // --- Kalkulasi ROM (Range of Motion) ---
    // Lurus ~140, Ditekuk ~100
    if (140.0 - 100.0 > 0) {
      double rom = ((140.0 - angle) / (140.0 - 100.0)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

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
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        }
        break;

      case PushUpState.goingDown:
        if (angle <= bentAngle) {
          // Analisis Tempo Eksentrik
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 1000) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

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
          _phaseStartTime = DateTime.now(); // Timer konsentrik
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
