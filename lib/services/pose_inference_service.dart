import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'dart:ui';

class InferenceResult {
  final List<Pose> poses;
  final SegmentationMask? mask;
  final double brightness;

  InferenceResult({required this.poses, this.mask, required this.brightness});
}

class PoseInferenceService {
  final PoseDetector _cameraPoseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final PoseDetector _staticPoseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    mode: SegmenterMode.stream,
    enableRawSizeMask: false,
  );

  bool _isProcessing = false;
  final List<Map<PoseLandmarkType, PoseLandmark>> _previousPosesLandmarks = [];
  final double _emaAlpha = 0.5; // 0.0 (freeze) to 1.0 (raw/no smoothing). 0.5 is a good balance.

  Future<InferenceResult?> processStaticImage(String filePath) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final poses = await _staticPoseDetector.processImage(inputImage);

      return InferenceResult(poses: poses, mask: null, brightness: 255.0);
    } catch (e) {
      debugPrint("Error processing static image: $e");
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  Future<InferenceResult?> processCameraImage(
    CameraImage image,
    int sensorOrientation,
    CameraLensDirection lensDirection,
    DeviceOrientation deviceOrientation,
    bool enableSegmentation,
  ) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(
        image,
        sensorOrientation,
        lensDirection,
        deviceOrientation,
      );
      if (inputImage == null) return null;

      final poses = await _cameraPoseDetector.processImage(inputImage);
      
      // Apply EMA smoothing to the poses
      final smoothedPoses = <Pose>[];
      if (poses.isEmpty) {
        _previousPosesLandmarks.clear();
      } else {
        for (int i = 0; i < poses.length; i++) {
          final rawPose = poses[i];
          if (_previousPosesLandmarks.length <= i) {
            _previousPosesLandmarks.add(rawPose.landmarks);
            smoothedPoses.add(rawPose);
            continue;
          }
          
          final prevLandmarks = _previousPosesLandmarks[i];
          final smoothedLandmarks = <PoseLandmarkType, PoseLandmark>{};
          
          for (final entry in rawPose.landmarks.entries) {
            final type = entry.key;
            final rawLandmark = entry.value;
            final prevLandmark = prevLandmarks[type];
            
            if (prevLandmark != null) {
              final smoothedX = prevLandmark.x + _emaAlpha * (rawLandmark.x - prevLandmark.x);
              final smoothedY = prevLandmark.y + _emaAlpha * (rawLandmark.y - prevLandmark.y);
              final smoothedZ = prevLandmark.z + _emaAlpha * (rawLandmark.z - prevLandmark.z);
              
              smoothedLandmarks[type] = PoseLandmark(
                type: type,
                x: smoothedX,
                y: smoothedY,
                z: smoothedZ,
                likelihood: rawLandmark.likelihood,
              );
            } else {
              smoothedLandmarks[type] = rawLandmark;
            }
          }
          
          _previousPosesLandmarks[i] = smoothedLandmarks;
          smoothedPoses.add(Pose(landmarks: smoothedLandmarks));
        }
      }
      
      SegmentationMask? mask;

      if (enableSegmentation) {
        mask = await _segmenter.processImage(inputImage);
      }

      final brightness = _calculateBrightness(image);

      return InferenceResult(poses: smoothedPoses, mask: mask, brightness: brightness);
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateBrightness(CameraImage image) {
    if (image.planes.isEmpty) return 255.0;

    final bytes = image.planes[0].bytes;
    if (bytes.isEmpty) return 255.0;

    int total = 0;
    int sampleStep = (bytes.length / 1000).ceil();
    if (sampleStep < 1) sampleStep = 1;

    int count = 0;
    for (int i = 0; i < bytes.length; i += sampleStep) {
      total += bytes[i];
      count++;
    }

    return count > 0 ? (total / count) : 255.0;
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    int sensorOrientation,
    CameraLensDirection lensDirection,
    DeviceOrientation deviceOrientation,
  ) {
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
      adjustedRotation =
          (sensorOrientation - deviceOrientationDegrees + 360) % 360;
    }

    final rotation =
        InputImageRotationValue.fromRawValue(adjustedRotation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
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
    _cameraPoseDetector.close();
    _staticPoseDetector.close();
    _segmenter.close();
  }
}
