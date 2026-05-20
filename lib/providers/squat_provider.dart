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
  
  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  DateTime? _phaseStartTime;
  final List<Offset> _trajectoryPoints = [];

  Pose? _currentPose;
  bool _isGoodPosture = false;

  int get repCount => _repCount;
  String get status => _status;
  double get kneeAngle => _kneeAngle;
  Pose? get currentPose => _currentPose;
  bool get isGoodPosture => _isGoodPosture;
  bool get hasStarted => _hasStarted;
  double get romPercentage => _romPercentage;
  String get tempoStatus => _tempoStatus;
  List<Offset> get trajectoryPoints => _trajectoryPoints;

  void reset() {
    _currentState = SquatState.standing;
    _repCount = 0;
    _status = "Siap...";
    _kneeAngle = 0.0;
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
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final minAngle = EnvConfig.squatMinAngle;
    final maxAngle = EnvConfig.squatMaxAngle;
    final threshold = EnvConfig.aiConfidenceThreshold;

    // Trajectory tracking (menggunakan titik pinggul)
    if (leftHip != null) {
      _trajectoryPoints.add(Offset(leftHip.x, leftHip.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    // --- Validasi landmark minimum ---
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

    // =============================================
    // ANTI-TIDURAN / REBAHAN — MULTI-LAYER CHECK
    // =============================================

    // CHECK 1: Urutan segmen vertikal ketat (Y semakin besar ke bawah layar)
    // Bahu HARUS di atas pinggul, pinggul HARUS di atas lutut
    // (ankle boleh lebih tinggi saat squat dalam)
    if (leftShoulder.y >= leftHip.y || leftHip.y >= leftKnee.y) {
       _status = "Berdirilah dengan tegak!";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    // CHECK 2: Sudut torso terhadap garis vertikal
    // Torso = garis dari hip ke shoulder. Saat berdiri, torso hampir vertikal.
    // Saat tiduran, torso hampir horizontal.
    final torsoAngleFromVertical = _calculateTorsoAngle(leftShoulder, leftHip);
    if (torsoAngleFromVertical > 50.0) {
       _status = "Badan terlalu miring! Berdiri tegak.";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    // CHECK 3: Rasio aspek tubuh — tinggi vertikal harus DOMINAN vs lebar horizontal
    // Menggunakan titik tertinggi (bahu) dan terendah (ankle) untuk body span
    final bodyTopY = math.min(leftShoulder.y, rightShoulder?.y ?? leftShoulder.y);
    final bodyBottomY = math.max(leftAnkle.y, rightAnkle?.y ?? leftAnkle.y);
    final bodyLeftX = math.min(leftShoulder.x, leftAnkle.x);
    final bodyRightX = math.max(leftShoulder.x, leftAnkle.x);

    final verticalSpan = (bodyBottomY - bodyTopY).abs();
    final horizontalSpan = (bodyRightX - bodyLeftX).abs();

    // Tubuh vertikal harus minimal 1.2x lebar horizontal (sebelumnya 0.5x, terlalu lemah)
    if (verticalSpan < horizontalSpan * 1.2) {
       _status = "Tolong berdirikan badan Anda!";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    // CHECK 4: Jarak vertikal shoulder-ke-hip harus cukup signifikan
    // (mencegah kasus orang rebahan di mana shoulder dan hip hampir sejajar Y)
    final shoulderHipVerticalDist = (leftHip.y - leftShoulder.y).abs();
    final shoulderHipHorizontalDist = (leftHip.x - leftShoulder.x).abs();
    if (shoulderHipVerticalDist < shoulderHipHorizontalDist) {
       _status = "Posisi tubuh horizontal terdeteksi!";
       _isGoodPosture = false;
       notifyListeners();
       return;
    }

    // --- Kalkulasi sudut lutut ---
    final angle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    _kneeAngle = angle;

    // --- Kalkulasi ROM (Range of Motion) ---
    if (maxAngle - minAngle > 0) {
      double rom = ((maxAngle - angle) / (maxAngle - minAngle)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    double lowestAnkleY = leftAnkle.y;
    if (rightAnkle != null && rightAnkle.likelihood > threshold) {
      lowestAnkleY = math.max(lowestAnkleY, rightAnkle.y);
    }
    
    // Jarak vertikal pinggul ke lantai (engkel terendah)
    final currentYDistance = lowestAnkleY - leftHip.y;

    _analyzeSquatState(angle, minAngle, maxAngle, currentYDistance);
    notifyListeners();
  }

  /// Menghitung sudut torso terhadap garis vertikal (0° = tegak lurus, 90° = rebahan)
  double _calculateTorsoAngle(PoseLandmark shoulder, PoseLandmark hip) {
    final dx = (hip.x - shoulder.x).abs();
    final dy = (hip.y - shoulder.y).abs();
    // atan2(horizontal, vertical) → 0° saat tegak, 90° saat rebahan
    final radians = math.atan2(dx, dy);
    return radians * 180 / math.pi;
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
          _phaseStartTime = DateTime.now(); // Mulai timer tempo eksentrik
          _tempoStatus = "";
        }
        break;

      case SquatState.goingDown:
        if (angle <= minAngle) {
          // Analisis Tempo Eksentrik
          if (_phaseStartTime != null) {
            final ms = DateTime.now().difference(_phaseStartTime!).inMilliseconds;
            if (ms < 1200) {
              _tempoStatus = "Terlalu Cepat!";
            } else {
              _tempoStatus = "Tempo Bagus";
            }
          }

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
          _phaseStartTime = DateTime.now(); // Mulai timer tempo konsentrik
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
