import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../services/pose_inference_service.dart';
import '../../providers/squat_provider.dart';
import '../painters/pose_painter.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late PoseInferenceService _inferenceService;
  int _cameraIndex = 1; 
  
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
      context.read<SquatProvider>().reset();
    });
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
        final poses = await _inferenceService.processCameraImage(
          image, 
          cameraDescription.sensorOrientation
        );
        
        if (poses.isNotEmpty && mounted) {
          context.read<SquatProvider>().processPose(poses.first);
        }
      });
      
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final squatProvider = context.watch<SquatProvider>();
    
    final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final Size imageSize = isPortrait
        ? Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width)
        : Size(_controller!.value.previewSize!.width, _controller!.value.previewSize!.height);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Squat Counter")),
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
                  if (!squatProvider.hasStarted)
                    CustomPaint(
                      painter: SilhouettePainter(),
                      size: Size.infinite,
                    ),
                  if (squatProvider.currentPose != null)
                    CustomPaint(
                      painter: PosePainter(
                        squatProvider.currentPose!,
                        imageSize,
                        squatProvider.isGoodPosture,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: _buildOverlayUI(squatProvider),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, squatProvider.repCount);
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

  Widget _buildOverlayUI(SquatProvider provider) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reps: ${provider.repCount}", 
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 5),
          Text(
            provider.status, 
            style: TextStyle(
              color: provider.isGoodPosture ? Colors.greenAccent : Colors.yellowAccent, 
              fontSize: 18,
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 5),
          Text(
            "Sudut Lutut: ${provider.kneeAngle.toStringAsFixed(0)}°", 
            style: const TextStyle(color: Colors.grey, fontSize: 14)
          ),
        ],
      ),
    );
  }
}

class SilhouettePainter extends CustomPainter {
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

