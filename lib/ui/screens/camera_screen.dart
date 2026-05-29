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
import '../../providers/jumpingjack_provider.dart';
import '../../providers/benchdips_provider.dart';
import '../../providers/plank_provider.dart';
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
      case ExerciseType.jumpingJack:
        context.read<JumpingJackProvider>().reset();
        break;
      case ExerciseType.benchDips:
        context.read<BenchDipsProvider>().reset();
        break;
      case ExerciseType.plank:
        context.read<PlankProvider>().reset();
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
      case ExerciseType.jumpingJack:
        context.read<JumpingJackProvider>().processPose(pose);
        break;
      case ExerciseType.benchDips:
        context.read<BenchDipsProvider>().processPose(pose);
        break;
      case ExerciseType.plank:
        context.read<PlankProvider>().processPose(pose);
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
      case ExerciseType.jumpingJack:
        return context.read<JumpingJackProvider>().repCount;
      case ExerciseType.benchDips:
        return context.read<BenchDipsProvider>().repCount;
      case ExerciseType.plank:
        return context.read<PlankProvider>().repCount;
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
      case ExerciseType.jumpingJack:
        return context.select<JumpingJackProvider, String>((p) => p.status);
      case ExerciseType.benchDips:
        return context.select<BenchDipsProvider, String>((p) => p.status);
      case ExerciseType.plank:
        return context.select<PlankProvider, String>((p) => p.status);
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
      case ExerciseType.jumpingJack:
        return context.select<JumpingJackProvider, int>((p) => p.repCount);
      case ExerciseType.benchDips:
        return context.select<BenchDipsProvider, int>((p) => p.repCount);
      case ExerciseType.plank:
        return context.select<PlankProvider, int>((p) => p.repCount);
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
      case ExerciseType.jumpingJack:
        return context.select<JumpingJackProvider, double>((p) => p.armAngle);
      case ExerciseType.benchDips:
        return context.select<BenchDipsProvider, double>((p) => p.elbowAngle);
      case ExerciseType.plank:
        return context.select<PlankProvider, double>((p) => p.plankAngle);
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
      case ExerciseType.jumpingJack:
        return context.select<JumpingJackProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.benchDips:
        return context.select<BenchDipsProvider, bool>((p) => p.isGoodPosture);
      case ExerciseType.plank:
        return context.select<PlankProvider, bool>((p) => p.isGoodPosture);
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
      case ExerciseType.jumpingJack:
        return context.select<JumpingJackProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.benchDips:
        return context.select<BenchDipsProvider, Pose?>((p) => p.currentPose);
      case ExerciseType.plank:
        return context.select<PlankProvider, Pose?>((p) => p.currentPose);
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
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, double>((p) => p.romPercentage);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, double>((p) => p.romPercentage);
      case ExerciseType.plank: return context.select<PlankProvider, double>((p) => p.romPercentage);
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
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, String>((p) => p.tempoStatus);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, String>((p) => p.tempoStatus);
      case ExerciseType.plank: return context.select<PlankProvider, String>((p) => p.tempoStatus);
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
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.plank: return context.select<PlankProvider, List<Offset>>((p) => p.trajectoryPoints);
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
            widget.exerciseType == ExerciseType.plank 
                ? "Waktu: $reps dtk" 
                : "Reps: $reps", 
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


