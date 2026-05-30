import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size absoluteImageSize;
  final bool isGoodPosture;
  final List<Offset> trajectory;
  final SegmentationMask? mask;
  final bool isMirrored;

  PosePainter(this.pose, this.absoluteImageSize, this.isGoodPosture, [this.trajectory = const [], this.mask, this.isMirrored = true]);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isGoodPosture ? Colors.greenAccent : Colors.redAccent;

    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    Offset translate(double x, double y) {
      if (isMirrored) {
        return Offset(size.width - (x * scaleX), y * scaleY);
      } else {
        return Offset(x * scaleX, y * scaleY);
      }
    }

    if (trajectory.isNotEmpty) {
      final trajPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.blueAccent.withOpacity(0.5);
        
      for (int i = 0; i < trajectory.length - 1; i++) {
        canvas.drawLine(
          translate(trajectory[i].dx, trajectory[i].dy),
          translate(trajectory[i+1].dx, trajectory[i+1].dy),
          trajPaint,
        );
      }
    }

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final joint1 = pose.landmarks[type1];
      final joint2 = pose.landmarks[type2];
      if (joint1 != null && joint2 != null) {
        canvas.drawLine(
          translate(joint1.x, joint1.y),
          translate(joint2.x, joint2.y),
          paint,
        );
      }
    }

    // Draw left leg
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    
    // Draw right leg
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    
    // Draw torso
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Draw left arm
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    // Draw right arm
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Draw points
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(translate(landmark.x, landmark.y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose || 
           oldDelegate.isGoodPosture != isGoodPosture ||
           oldDelegate.trajectory.length != trajectory.length ||
           oldDelegate.mask != mask ||
           oldDelegate.isMirrored != isMirrored;
  }
}
