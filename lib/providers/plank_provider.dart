import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/constants/env_config.dart';

class PlankProvider extends ChangeNotifier {
  int _repCount = 0; // Represents seconds held
  String _status = "Siap... Ambil posisi plank.";
  double _plankAngle = 0.0;
  bool _isGoodPosture = false;
  bool _hasStarted = false;
  
  // Advanced PCD Features
  double _romPercentage = 0.0;
  String _tempoStatus = "";
  final List<Offset> _trajectoryPoints = [];
  
  Pose? _currentPose;
  
  // Timer state
  int _accumulatedTimeMs = 0;
  DateTime? _lastFrameTime;

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
    _repCount = 0;
    _status = "Siap... Ambil posisi plank.";
    _plankAngle = 0.0;
    _isGoodPosture = false;
    _hasStarted = false;
    _currentPose = null;
    _romPercentage = 0.0;
    _tempoStatus = "";
    _trajectoryPoints.clear();
    _accumulatedTimeMs = 0;
    _lastFrameTime = null;
    notifyListeners();
  }

  void processPose(Pose pose) {
    _currentPose = pose;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final threshold = EnvConfig.aiConfidenceThreshold;

    if (leftHip != null) {
      _trajectoryPoints.add(Offset(leftHip.x, leftHip.y));
      if (_trajectoryPoints.length > 20) {
        _trajectoryPoints.removeAt(0);
      }
    }

    if (leftShoulder == null || leftHip == null || leftAnkle == null) {
      _status = "Tubuh tidak terlihat utuh";
      _isGoodPosture = false;
      _lastFrameTime = null;
      notifyListeners();
      return;
    }

    if (leftShoulder.likelihood < threshold ||
        leftHip.likelihood < threshold ||
        leftAnkle.likelihood < threshold) {
      _status = "Mendeteksi...";
      _isGoodPosture = false;
      _lastFrameTime = null;
      notifyListeners();
      return;
    }

    // CHECK: Tubuh harus mendatar (prone)
    final totalVertical = (leftAnkle.y - leftShoulder.y).abs();
    final totalHorizontal = (leftAnkle.x - leftShoulder.x).abs();

    if (totalVertical > totalHorizontal * 1.5) {
      _status = "Posisi Plank: badan harus mendatar!";
      _isGoodPosture = false;
      _lastFrameTime = null;
      notifyListeners();
      return;
    }

    // Hitung sudut badan (Shoulder - Hip - Ankle)
    final angle = _calculateAngle(leftShoulder, leftHip, leftAnkle);
    _plankAngle = angle;

    // ROM calculation for visual feedback (180 is straight, < 140 is bad)
    if (180.0 - 140.0 > 0) {
      double rom = ((angle - 140.0) / (180.0 - 140.0)) * 100;
      _romPercentage = rom.clamp(0.0, 100.0);
    }

    if (angle > 155.0) {
      _isGoodPosture = true;
      if (!_hasStarted) _hasStarted = true;
      
      _status = "Bagus! Tahan posisi...";
      
      final now = DateTime.now();
      if (_lastFrameTime != null) {
        _accumulatedTimeMs += now.difference(_lastFrameTime!).inMilliseconds;
        _repCount = _accumulatedTimeMs ~/ 1000;
      }
      _lastFrameTime = now;
    } else {
      _isGoodPosture = false;
      _status = "Luruskan punggung dan kaki Anda!";
      _lastFrameTime = null;
    }

    notifyListeners();
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
