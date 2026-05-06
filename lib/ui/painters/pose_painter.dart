import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size absoluteImageSize;
  final bool isGoodPosture;

  PosePainter(this.pose, this.absoluteImageSize, this.isGoodPosture);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isGoodPosture ? Colors.greenAccent : Colors.redAccent;

    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    Offset translate(double x, double y) {
      // Mirroring for front camera
      return Offset(size.width - (x * scaleX), y * scaleY);
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
    return oldDelegate.pose != pose || oldDelegate.isGoodPosture != isGoodPosture;
  }
}
