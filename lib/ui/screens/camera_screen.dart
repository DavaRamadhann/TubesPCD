import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'dart:io';

import '../../core/constants/exercise_type.dart';
import '../../services/pose_inference_service.dart';
import '../../providers/squat_provider.dart';
import '../../providers/situp_provider.dart';
import '../../providers/pushup_provider.dart';
import '../../providers/shouldertap_provider.dart';
import '../../providers/lunges_provider.dart';
import '../../providers/burpees_provider.dart';
import '../painters/pose_painter.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;

  const CameraScreen({
    Key? key,
    required this.cameras,
    required this.exerciseType,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late PoseInferenceService _inferenceService;
  int _cameraIndex = 1;
  bool _isLandscape = false;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;
  
  bool _enableSegmentation = false;
  SegmentationMask? _currentMask;
  double _brightness = 255.0;
  
  @override
  void initState() {
    super.initState();
    _inferenceService = PoseInferenceService();
    
    if (widget.cameras.isNotEmpty) {
      _cameraIndex = widget.cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_cameraIndex == -1) _cameraIndex = 0;
      _initializeCamera(widget.cameras[_cameraIndex]);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetProvider();
    });
  }

  void _resetProvider() {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        context.read<SquatProvider>().reset();
        break;
      case ExerciseType.sitUp:
        context.read<SitUpProvider>().reset();
        break;
      case ExerciseType.pushUp:
        context.read<PushUpProvider>().reset();
        break;
      case ExerciseType.shoulderTap:
        context.read<ShoulderTapProvider>().reset();
        break;
      case ExerciseType.lunges:
        context.read<LungesProvider>().reset();
        break;
      case ExerciseType.burpees:
        context.read<BurpeesProvider>().reset();
        break;
    }
  }

  void _processPose(Pose pose) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        context.read<SquatProvider>().processPose(pose);
        break;
      case ExerciseType.sitUp:
        context.read<SitUpProvider>().processPose(pose);
        break;
      case ExerciseType.pushUp:
        context.read<PushUpProvider>().processPose(pose);
        break;
      case ExerciseType.shoulderTap:
        context.read<ShoulderTapProvider>().processPose(pose);
        break;
      case ExerciseType.lunges:
        context.read<LungesProvider>().processPose(pose);
        break;
      case ExerciseType.burpees:
        context.read<BurpeesProvider>().processPose(pose);
        break;
    }
  }

  int _getRepCount() {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.read<SquatProvider>().repCount;
      case ExerciseType.sitUp:
        return context.read<SitUpProvider>().repCount;
      case ExerciseType.pushUp:
        return context.read<PushUpProvider>().repCount;
      case ExerciseType.shoulderTap:
        return context.read<ShoulderTapProvider>().repCount;
      case ExerciseType.lunges:
        return context.read<LungesProvider>().repCount;
      case ExerciseType.burpees:
        return context.read<BurpeesProvider>().repCount;
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      
      await _controller!.startImageStream((CameraImage image) async {
        final result = await _inferenceService.processCameraImage(
          image, 
          cameraDescription.sensorOrientation,
          cameraDescription.lensDirection,
          _deviceOrientation,
          _enableSegmentation,
        );
        
        if (result != null && mounted) {
          setState(() {
            _brightness = result.brightness;
            _currentMask = result.mask;
          });
          
          if (result.poses.isNotEmpty) {
            _processPose(result.poses.first);
          }
        }
      });
      
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      _deviceOrientation = _isLandscape
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void dispose() {
    // Kembalikan ke portrait saat keluar dari kamera
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _controller?.stopImageStream();
    _controller?.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  // --- Helper getters untuk data dari provider aktif ---
  String _getStatus(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, String>((p) => p.status);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, String>((p) => p.status);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, String>((p) => p.status);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, String>((p) => p.status);
      case ExerciseType.lunges:
        return context.select<LungesProvider, String>((p) => p.status);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, String>((p) => p.status);
    }
  }

  int _getReps(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, int>((p) => p.repCount);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, int>((p) => p.repCount);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, int>((p) => p.repCount);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, int>((p) => p.repCount);
      case ExerciseType.lunges:
        return context.select<LungesProvider, int>((p) => p.repCount);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, int>((p) => p.repCount);
    }
  }

  double _getAngle(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, double>((p) => p.kneeAngle);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, double>((p) => p.bodyAngle);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, double>((p) => p.elbowAngle);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, double>((p) => p.plankAngle);
      case ExerciseType.lunges:
        return context.select<LungesProvider, double>((p) => p.kneeAngle);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, double>((p) => p.torsoAngle);
    }
  }

  bool _getIsGoodPosture(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.lunges:
        return context.select<LungesProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, bool>((p) => p.isGoodPosture);
    }
  }

  bool _getHasStarted(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, bool>((p) => p.hasStarted);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, bool>((p) => p.hasStarted);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, bool>((p) => p.hasStarted);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, bool>((p) => p.hasStarted);
      case ExerciseType.lunges:
        return context.select<LungesProvider, bool>((p) => p.hasStarted);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, bool>((p) => p.hasStarted);
    }
  }

  Pose? _getCurrentPose(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return context.select<SquatProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.sitUp:
        return context.select<SitUpProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.pushUp:
        return context.select<PushUpProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.shoulderTap:
        return context.select<ShoulderTapProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.lunges:
        return context.select<LungesProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.burpees:
        return context.select<BurpeesProvider, Pose?>((p) => p.currentPose);
    }
  }

  double _getRom(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, double>((p) => p.romPercentage);
      case ExerciseType.sitUp: return context.select<SitUpProvider, double>((p) => p.romPercentage);
      case ExerciseType.pushUp: return context.select<PushUpProvider, double>((p) => p.romPercentage);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, double>((p) => p.romPercentage);
      case ExerciseType.lunges: return context.select<LungesProvider, double>((p) => p.romPercentage);
      case ExerciseType.burpees: return context.select<BurpeesProvider, double>((p) => p.romPercentage);
    }
  }
  
  String _getTempo(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, String>((p) => p.tempoStatus);
      case ExerciseType.sitUp: return context.select<SitUpProvider, String>((p) => p.tempoStatus);
      case ExerciseType.pushUp: return context.select<PushUpProvider, String>((p) => p.tempoStatus);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, String>((p) => p.tempoStatus);
      case ExerciseType.lunges: return context.select<LungesProvider, String>((p) => p.tempoStatus);
      case ExerciseType.burpees: return context.select<BurpeesProvider, String>((p) => p.tempoStatus);
    }
  }

  List<Offset> _getTrajectory(BuildContext context) {
    switch (widget.exerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.sitUp: return context.select<SitUpProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.pushUp: return context.select<PushUpProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.lunges: return context.select<LungesProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.burpees: return context.select<BurpeesProvider, List<Offset>>((p) => p.trajectoryPoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = _getStatus(context);
    final reps = _getReps(context);
    final angle = _getAngle(context);
    final isGoodPosture = _getIsGoodPosture(context);
    final hasStarted = _getHasStarted(context);
    final currentPose = _getCurrentPose(context);
    final rom = _getRom(context);
    final tempo = _getTempo(context);
    final trajectory = _getTrajectory(context);
    
    final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final Size imageSize = isPortrait
        ? Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width)
        : Size(_controller!.value.previewSize!.width, _controller!.value.previewSize!.height);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.exerciseType.label} Counter"),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _enableSegmentation = !_enableSegmentation;
              });
            },
            icon: Icon(_enableSegmentation ? Icons.blur_on : Icons.blur_off),
            tooltip: 'Toggle Blur Background',
          ),
          IconButton(
            onPressed: _toggleOrientation,
            icon: Icon(_isLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape),
            tooltip: _isLandscape ? 'Mode Portrait' : 'Mode Landscape',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: imageSize.width,
              height: imageSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller!),
                  if (!hasStarted)
                    CustomPaint(
                      painter: _getSilhouettePainter(),
                      size: Size.infinite,
                    ),
                  if (currentPose != null)
                    CustomPaint(
                      painter: PosePainter(
                        currentPose,
                        imageSize,
                        isGoodPosture,
                        trajectory,
                        _currentMask,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: _buildOverlayUI(status, reps, angle, isGoodPosture, rom, tempo),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, _getRepCount());
                },
                icon: const Icon(Icons.stop),
                label: const Text("Selesai Latihan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  CustomPainter _getSilhouettePainter() {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return SquatSilhouettePainter();
      case ExerciseType.sitUp:
        return SitUpSilhouettePainter();
      case ExerciseType.pushUp:
        return PushUpSilhouettePainter();
      case ExerciseType.shoulderTap:
        return ShoulderTapSilhouettePainter();
      case ExerciseType.lunges:
        return LungesSilhouettePainter();
      case ExerciseType.burpees:
        return BurpeesSilhouettePainter();
    }
  }

  Widget _buildOverlayUI(String status, int reps, double angle, bool isGoodPosture, double rom, String tempo) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_brightness < 50)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text("⚠️ Ruangan terlalu gelap!", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          Text(
            "Reps: $reps", 
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 5),
          Text(
            status, 
            style: TextStyle(
              color: isGoodPosture ? Colors.greenAccent : Colors.yellowAccent, 
              fontSize: 16,
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 5),
          Text(
            "${widget.exerciseType.angleLabel}: ${angle.toStringAsFixed(0)}°", 
            style: const TextStyle(color: Colors.grey, fontSize: 14)
          ),
          if (tempo.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              "Tempo: $tempo", 
              style: TextStyle(color: tempo.contains("Bagus") ? Colors.greenAccent : Colors.redAccent, fontSize: 14)
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("ROM: ", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Expanded(
                child: LinearProgressIndicator(
                  value: rom / 100,
                  backgroundColor: Colors.white24,
                  color: Colors.blueAccent,
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 8),
              Text("${rom.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}

// --- Siluet panduan untuk setiap exercise ---

class SquatSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    
    // Kepala
    canvas.drawCircle(Offset(centerX, size.height * 0.25), size.height * 0.05, paint);
    
    // Badan (Tulang Belakang)
    canvas.drawLine(Offset(centerX, size.height * 0.3), Offset(centerX, size.height * 0.55), paint);
    
    // Tangan (Membentang sedikit ke bawah)
    canvas.drawLine(Offset(centerX, size.height * 0.35), Offset(centerX - size.width * 0.15, size.height * 0.45), paint);
    canvas.drawLine(Offset(centerX, size.height * 0.35), Offset(centerX + size.width * 0.15, size.height * 0.45), paint);
    
    // Kaki (Dibuka sedikit)
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX - size.width * 0.1, size.height * 0.8), paint);
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX + size.width * 0.1, size.height * 0.8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SitUpSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final centerY = size.height * 0.65;
    
    // Kepala (di kiri, rebahan)
    canvas.drawCircle(Offset(size.width * 0.2, centerY - size.height * 0.03), size.height * 0.04, paint);
    
    // Badan (horizontal, dari kepala ke pinggul)
    canvas.drawLine(
      Offset(size.width * 0.25, centerY),
      Offset(size.width * 0.55, centerY),
      paint,
    );
    
    // Kaki — ditekuk (lutut ke atas, kaki ke bawah)
    canvas.drawLine(
      Offset(size.width * 0.55, centerY),
      Offset(size.width * 0.65, centerY - size.height * 0.12),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, centerY - size.height * 0.12),
      Offset(size.width * 0.7, centerY + size.height * 0.02),
      paint,
    );
    
    // Tangan di belakang kepala
    canvas.drawLine(
      Offset(size.width * 0.3, centerY),
      Offset(size.width * 0.22, centerY - size.height * 0.05),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PushUpSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final bodyY = size.height * 0.55;
    
    // Kepala
    canvas.drawCircle(Offset(size.width * 0.22, bodyY - size.height * 0.06), size.height * 0.035, paint);
    
    // Badan (horizontal — dari shoulder ke hip)
    canvas.drawLine(
      Offset(size.width * 0.25, bodyY),
      Offset(size.width * 0.65, bodyY),
      paint,
    );
    
    // Kaki (hip ke ankle, sedikit miring ke bawah)
    canvas.drawLine(
      Offset(size.width * 0.65, bodyY),
      Offset(size.width * 0.85, bodyY + size.height * 0.03),
      paint,
    );
    
    // Tangan (shoulder ke bawah — posisi push-up)
    canvas.drawLine(
      Offset(size.width * 0.25, bodyY),
      Offset(size.width * 0.28, bodyY + size.height * 0.1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, bodyY + size.height * 0.1),
      Offset(size.width * 0.3, bodyY + size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShoulderTapSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final headY = size.height * 0.35;
    final shoulderY = size.height * 0.45;
    final shoulderWidth = size.width * 0.25;
    final armLength = size.height * 0.2;

    // Kepala
    canvas.drawCircle(Offset(centerX, headY), size.height * 0.04, paint);

    // Bahu (Horizontal)
    canvas.drawLine(
      Offset(centerX - shoulderWidth, shoulderY),
      Offset(centerX + shoulderWidth, shoulderY),
      paint,
    );

    // Tangan Kiri (Menumpu lurus ke bawah)
    canvas.drawLine(
      Offset(centerX - shoulderWidth, shoulderY),
      Offset(centerX - shoulderWidth, shoulderY + armLength),
      paint,
    );

    // Tangan Kanan (Menepuk menyentuh bahu kiri)
    canvas.drawLine(
      Offset(centerX + shoulderWidth, shoulderY),
      Offset(centerX + shoulderWidth * 0.3, shoulderY + armLength * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + shoulderWidth * 0.3, shoulderY + armLength * 0.5),
      Offset(centerX - shoulderWidth, shoulderY), // Menyentuh bahu kiri
      paint,
    );

    // Badan/Pinggul (Tengah)
    canvas.drawLine(
      Offset(centerX, shoulderY),
      Offset(centerX, shoulderY + armLength),
      paint,
    );

    // Kaki (Merentang di belakang)
    canvas.drawLine(
      Offset(centerX, shoulderY + armLength),
      Offset(centerX - shoulderWidth * 0.5, shoulderY + armLength * 1.3),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, shoulderY + armLength),
      Offset(centerX + shoulderWidth * 0.5, shoulderY + armLength * 1.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LungesSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    
    // Kepala
    canvas.drawCircle(Offset(centerX, size.height * 0.25), size.height * 0.05, paint);
    
    // Badan
    canvas.drawLine(Offset(centerX, size.height * 0.3), Offset(centerX, size.height * 0.55), paint);
    
    // Kaki depan (lutut menekuk 90 derajat)
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX + size.width * 0.15, size.height * 0.65), paint);
    canvas.drawLine(Offset(centerX + size.width * 0.15, size.height * 0.65), Offset(centerX + size.width * 0.15, size.height * 0.8), paint);
    
    // Kaki belakang (lutut hampir menyentuh tanah)
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX - size.width * 0.15, size.height * 0.75), paint);
    canvas.drawLine(Offset(centerX - size.width * 0.15, size.height * 0.75), Offset(centerX - size.width * 0.25, size.height * 0.8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BurpeesSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    
    // Kepala
    canvas.drawCircle(Offset(centerX, size.height * 0.25), size.height * 0.05, paint);
    
    // Badan (Tulang Belakang)
    canvas.drawLine(Offset(centerX, size.height * 0.3), Offset(centerX, size.height * 0.55), paint);
    
    // Tangan (Membentang sedikit ke bawah/samping seperti siap loncat)
    canvas.drawLine(Offset(centerX, size.height * 0.35), Offset(centerX - size.width * 0.15, size.height * 0.45), paint);
    canvas.drawLine(Offset(centerX, size.height * 0.35), Offset(centerX + size.width * 0.15, size.height * 0.45), paint);
    
    // Kaki (Dibuka sedikit, pose siap loncat/squat)
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX - size.width * 0.1, size.height * 0.8), paint);
    canvas.drawLine(Offset(centerX, size.height * 0.55), Offset(centerX + size.width * 0.1, size.height * 0.8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
