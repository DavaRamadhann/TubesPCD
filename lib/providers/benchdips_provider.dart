import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum BenchDipsState { armsExtended, goingDown, atBottom, comingUp }

class BenchDipsProvider extends ChangeNotifier {
  BenchDipsState _currentState = BenchDipsState.armsExtended;
  int _repCount = 0;
  String _status = "Siap... Duduk di bangku.";
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
    _currentState = BenchDipsState.armsExtended;
    _repCount = 0;
    _status = "Siap... Duduk di bangku.";
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
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // Trajectory tracking (menggunakan pinggul)
    if (leftHip != null) {
      _trajectoryPoints.add(Offset(leftHip.x, leftHip.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    if (leftShoulder == null || leftElbow == null || leftWrist == null ||
        leftHip == null || leftKnee == null || leftAnkle == null ||
        rightShoulder == null || rightElbow == null || rightWrist == null ||
        rightHip == null || rightKnee == null || rightAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold ||
        leftElbow.likelihood < threshold ||
        leftWrist.likelihood < threshold ||
        leftHip.likelihood < threshold ||
        leftKnee.likelihood < threshold ||
        leftAnkle.likelihood < threshold ||
        rightShoulder.likelihood < threshold ||
        rightElbow.likelihood < threshold ||
        rightWrist.likelihood < threshold ||
        rightHip.likelihood < threshold ||
        rightKnee.likelihood < threshold ||
        rightAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // =============================================
    // VALIDASI POSISI BENCH DIPS
    // =============================================

    // CHECK 1: Pastikan user duduk (lutut ditekuk), bukan berdiri
    // Saat duduk di bangku untuk bench dips, lutut ditekuk ~90°
    // Saat berdiri, lutut lurus ~170°
    final leftKneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    final rightKneeAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
    final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    if (avgKneeAngle > 135.0) {
      _status = "Duduk di bangku! Tekuk lutut.";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // CHECK 2: Pastikan pinggul sejajar atau di bawah lutut (posisi duduk)
    // Saat berdiri: pinggul di atas lutut (hip.y << knee.y)
    // Saat duduk: pinggul sejajar atau di bawah lutut (hip.y >= knee.y)
    final hipMidY = (leftHip.y + rightHip.y) / 2;
    final kneeMidY = (leftKnee.y + rightKnee.y) / 2;

    if (hipMidY < kneeMidY - 30) {
      _status = "Duduk di bangku! Turunkan pinggul.";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // CHECK 3: Pastikan badan tidak horizontal (bukan push-up/plank)
    final shoulderHipY = ((leftShoulder.y + rightShoulder.y) / 2) - ((leftHip.y + rightHip.y) / 2);
    final shoulderHipX = ((leftShoulder.x + rightShoulder.x) / 2) - ((leftHip.x + rightHip.x) / 2);
    if (shoulderHipY.abs() < shoulderHipX.abs() * 1.5) {
      _status = "Bench dips: duduk tegak, bukan tiduran!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // --- Kalkulasi sudut siku rata-rata kedua sisi ---
    final leftElbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    final rightElbowAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
    final avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    _elbowAngle = avgElbowAngle;

    // --- Kalkulasi ROM (Range of Motion) ---
    if (140.0 - 120.0 > 0) {
      double rom = ((140.0 - avgElbowAngle) / (140.0 - 120.0)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    _analyzeState(avgElbowAngle);
    notifyListeners();
  }

  void _analyzeState(double angle) {
    const double extendedAngle = 140.0;
    const double bentAngle = 120.0;

    switch (_currentState) {
      case BenchDipsState.armsExtended:
        if (angle > extendedAngle) {
          _status = "Posisi OK. Turunkan badan!";
          _isGoodPosture = true;
        }
        if (angle < extendedAngle) {
          _hasStarted = true;
          _currentState = BenchDipsState.goingDown;
          _isValidRep = false;
          _status = "Turun...";
          _isGoodPosture = false;
          _phaseStartTime = DateTime.now();
          _tempoStatus = "";
        }
        break;

      case BenchDipsState.goingDown:
        if (angle <= bentAngle) {
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 800) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

          _currentState = BenchDipsState.atBottom;
          _isValidRep = true;
          _status = "Posisi Bagus! Naik!";
          _isGoodPosture = true;
        } else if (angle > extendedAngle + 5) {
          _currentState = BenchDipsState.armsExtended;
          _status = "Turun lebih dalam!";
          _isGoodPosture = false;
        }
        break;

      case BenchDipsState.atBottom:
        if (angle > bentAngle + 15) {
          _currentState = BenchDipsState.comingUp;
          _status = "Naik...";
          _phaseStartTime = DateTime.now();
        }
        break;

      case BenchDipsState.comingUp:
        if (angle > extendedAngle) {
          _currentState = BenchDipsState.armsExtended;

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
