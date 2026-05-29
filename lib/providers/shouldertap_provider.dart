import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

enum ShoulderTapState { plank, tapInProgress, bothTapped }

class ShoulderTapProvider extends ChangeNotifier {
  ShoulderTapState _currentState = ShoulderTapState.plank;
  int _repCount = 0;
  String _status = "Siap... Ambil posisi plank.";
  double _plankAngle = 0.0;
  bool _isValidRep = false;
  bool _hasStarted = false;

  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  DateTime? _phaseStartTime;
  final List<Offset> _trajectoryPoints = [];

  Pose? _currentPose;
  bool _isGoodPosture = false;

  bool _leftTapped = false;
  bool _rightTapped = false;

  int get repCount => _repCount;
  String get status => _status;
  double get plankAngle => _plankAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = ShoulderTapState.plank;
    _repCount = 0;
    _status = "Siap... Ambil posisi plank.";
    _plankAngle = 0.0;
    _isValidRep = false;
    _hasStarted = false;
    _currentPose = null;
    _isGoodPosture = false;
    _romPercentage = 0.0;
    _tempoStatus = "";
    _phaseStartTime = null;
    _leftTapped = false;
    _rightTapped = false;
    _trajectoryPoints.clear();
    notifyListeners();
  }

  double _distance(PoseLandmark a, PoseLandmark b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  void processPose(Pose pose) {
    _currentPose = pose;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    // Trajectory tracking (menggunakan bahu kiri)
    if (leftShoulder != null) {
      _trajectoryPoints.add(Offset(leftShoulder.x, leftShoulder.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    // --- Validasi landmark ---
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold ||
        rightShoulder.likelihood < threshold ||
        leftWrist.likelihood < threshold ||
        rightWrist.likelihood < threshold ||
        leftHip.likelihood < threshold ||
        leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // =============================================
    // VALIDASI POSISI PLANK HADAP DEPAN (FRONT-FACING)
    // =============================================

    // Hitung lebar bahu sebagai acuan jarak relatif yang adaptif
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    if (shoulderWidth < 5.0) return; // Mencegah pembagian nol

    // CHECK 1: Deteksi Posisi Berdiri (Jika berdiri, jarak vertikal Y bahu-pinggul sangat besar dibanding lebar bahu)
    final shoulderHipYDist = (leftHip.y - leftShoulder.y).abs();
    if (shoulderHipYDist > shoulderWidth * 1.5) {
      _status = "Ambil posisi plank menghadap kamera!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // CHECK 2: Jaga Pundak Tetap Sejajar (Menghindari miring berlebih)
    final shoulderSlope =
        (leftShoulder.y - rightShoulder.y).abs() / shoulderWidth;
    if (shoulderSlope > 0.35) {
      _status = "Jaga posisi pundak tetap sejajar!";
      _isGoodPosture = false;
      notifyListeners();
      return;
    }

    // Hitung juga kelurusan sudut tubuh samping-belakang (opsional visualisasi)
    final bodyLineAngle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
    _plankAngle = bodyLineAngle;

    final distRightHandToLeftShoulder = _distance(rightWrist, leftShoulder);
    final distLeftHandToRightShoulder = _distance(leftWrist, rightShoulder);

    // --- Perhitungan ROM (Range of Motion) ---
    // Ketika tangan menempel di lantai, jarak wrist-oppositeShoulder sekitar 1.2 * shoulderWidth
    // Ketika menepuk bahu, jarak mengecil hingga di bawah 0.6 * shoulderWidth
    final minDist = math.min(
      distRightHandToLeftShoulder,
      distLeftHandToRightShoulder,
    );
    final maxDist = shoulderWidth * 1.2;
    final targetDist = shoulderWidth * 0.55;

    double rom = ((maxDist - minDist) / (maxDist - targetDist)) * 100;
    _romPercentage = rom.clamp(0.0, 100.0);

    const double tapThreshold =
        0.6; // Sentuhan dianggap valid jika jarak < 0.6 * lebar bahu
    const double floorThreshold =
        1.0; // Tangan dianggap kembali ke lantai jika jarak > 1.0 * lebar bahu

    _analyzeShoulderTapState(
      distRightHandToLeftShoulder,
      distLeftHandToRightShoulder,
      shoulderWidth,
      tapThreshold,
      floorThreshold,
    );
    notifyListeners();
  }

  void _analyzeShoulderTapState(
    double distRightToLeft,
    double distLeftToRight,
    double shoulderWidth,
    double tapThresh,
    double floorThresh,
  ) {
    final double tapLimit = shoulderWidth * tapThresh;
    final double floorLimit = shoulderWidth * floorThresh;

    switch (_currentState) {
      case ShoulderTapState.plank:
        // Status awal: menunggu salah satu bahu di-tap
        if (distRightToLeft < tapLimit) {
          _leftTapped = true;
          _hasStarted = true;
          _currentState = ShoulderTapState.tapInProgress;
          _status = "Bahu kiri OK! Sekarang bahu kanan.";
          _isGoodPosture = true;
        } else if (distLeftToRight < tapLimit) {
          _rightTapped = true;
          _hasStarted = true;
          _currentState = ShoulderTapState.tapInProgress;
          _status = "Bahu kanan OK! Sekarang bahu kiri.";
          _isGoodPosture = true;
        } else {
          _status = "Plank OK. Tap bahu kiri & kanan.";
          _isGoodPosture = true;
        }
        break;

      case ShoulderTapState.tapInProgress:
        // Salah satu bahu sudah di-tap, mendeteksi tap berikutnya
        if (_leftTapped && !_rightTapped) {
          if (distLeftToRight < tapLimit) {
            _rightTapped = true;
            _currentState = ShoulderTapState.bothTapped;
            _status = "Bagus! Kembalikan tangan ke lantai.";
            _isGoodPosture = true;
          }
        } else if (_rightTapped && !_leftTapped) {
          if (distRightToLeft < tapLimit) {
            _leftTapped = true;
            _currentState = ShoulderTapState.bothTapped;
            _status = "Bagus! Kembalikan tangan ke lantai.";
            _isGoodPosture = true;
          }
        }
        break;

      case ShoulderTapState.bothTapped:
        // Kedua bahu sudah di-tap, tunggu hingga kembali ke posisi plank (dua tangan di lantai)
        if (distRightToLeft > floorLimit && distLeftToRight > floorLimit) {
          _repCount++;
          _currentState = ShoulderTapState.plank;
          _leftTapped = false;
          _rightTapped = false;
          _status = "REPETISI KE-$_repCount (GOOD!)";
          _isGoodPosture = true;
          _tempoStatus = "Bagus";
        }
        break;
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    var angle = radians * 180 / math.pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }
}
