import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:ui';

class PoseInferenceService {
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isProcessing = false;

  Future<List<Pose>> processCameraImage(
    CameraImage image,
    int sensorOrientation,
    CameraLensDirection lensDirection,
    DeviceOrientation deviceOrientation,
  ) async {
    if (_isProcessing) return [];
    _isProcessing = true;
    
    try {
      final inputImage = _inputImageFromCameraImage(
        image, sensorOrientation, lensDirection, deviceOrientation,
      );
      if (inputImage == null) return [];
      
      final poses = await _poseDetector.processImage(inputImage);
      return poses;
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    int sensorOrientation,
    CameraLensDirection lensDirection,
    DeviceOrientation deviceOrientation,
  ) {
    // Hitung rotasi berdasarkan orientasi device + sensor
    int deviceOrientationDegrees;
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        deviceOrientationDegrees = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceOrientationDegrees = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceOrientationDegrees = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceOrientationDegrees = 270;
        break;
    }

    int adjustedRotation;
    if (lensDirection == CameraLensDirection.front) {
      adjustedRotation = (sensorOrientation + deviceOrientationDegrees) % 360;
    } else {
      adjustedRotation = (sensorOrientation - deviceOrientationDegrees + 360) % 360;
    }

    final rotation = InputImageRotationValue.fromRawValue(adjustedRotation)
        ?? InputImageRotation.rotation0deg;
    
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // Jika tidak valid secara raw, kita asumsikan NV21 untuk Android, BGRA8888 untuk iOS
    final fallbackFormat = defaultTargetPlatform == TargetPlatform.iOS 
        ? InputImageFormat.bgra8888 
        : InputImageFormat.nv21;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format ?? fallbackFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void dispose() {
    _poseDetector.close();
  }
}
