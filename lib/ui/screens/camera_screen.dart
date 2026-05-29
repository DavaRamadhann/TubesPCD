import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'dart:io';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/exercise_type.dart';
import '../../models/exercise_config.dart';
import '../../models/program_session.dart';
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
import '../../providers/legraise_provider.dart';
import '../painters/pose_painter.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  // Program Mode
  final List<ExerciseConfig>? program;
  final String? programName;
  final int? transitionRest;

  // Single Mode
  final ExerciseType? exerciseType;
  final int targetReps;
  final int targetSets;
  final int restDuration;

  const CameraScreen({
    super.key,
    required this.cameras,
    this.program,
    this.programName,
    this.transitionRest,
    this.exerciseType,
    this.targetReps = 0,
    this.targetSets = 1,
    this.restDuration = 30,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late PoseInferenceService _inferenceService;
  int _cameraIndex = 1;
  bool _isLandscape = false;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;
  
  // Program states
  int _currentProgramIndex = 0;
  List<ProgramExerciseResult> _programResults = [];
  bool _isTransitioning = false;
  int _transitionSecondsRemaining = 0;

  // Set & Rest states
  int _currentSet = 1;
  bool _isResting = false;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  int _accumulatedReps = 0;
  bool _isWorkoutComplete = false;
  
  bool get _isProgramMode => widget.program != null && widget.program!.isNotEmpty;
  
  ExerciseType get _currentExerciseType {
    if (_isProgramMode) return widget.program![_currentProgramIndex].type;
    return widget.exerciseType ?? ExerciseType.squat;
  }
  
  int get _currentTargetReps {
    if (_isProgramMode) return widget.program![_currentProgramIndex].targetReps;
    return widget.targetReps;
  }
  
  int get _currentTargetSets {
    if (_isProgramMode) return widget.program![_currentProgramIndex].targetSets;
    return widget.targetSets;
  }
  
  int get _currentRestDuration {
    if (_isProgramMode) return widget.program![_currentProgramIndex].restDuration;
    return widget.restDuration;
  }
  
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
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        context.read<LegRaiseProvider>().reset();
        break;
    }
  }

  void _processPose(Pose pose) {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        context.read<LegRaiseProvider>().processPose(pose);
        break;
    }
  }

  int _getRepCount() {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.read<LegRaiseProvider>().repCount;
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
          
          if (result.poses.isNotEmpty && !_isResting && !_isTransitioning && !_isWorkoutComplete) {
            _processPose(result.poses.first);
            _checkSetCompletion();
          }
        }
      });
      
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  void _checkSetCompletion() {
    if ((_isProgramMode ? widget.program![_currentProgramIndex].targetReps : widget.targetReps) <= 0) return;
    
    final currentReps = _getRepCount();
    if (currentReps >= (_isProgramMode ? widget.program![_currentProgramIndex].targetReps : widget.targetReps)) {
      if (_currentSet < (_isProgramMode ? widget.program![_currentProgramIndex].targetSets : widget.targetSets)) {
        _startRest(currentReps);
      } else {
        _completeWorkout(currentReps);
      }
    }
  }

  void _startRest(int repsDone) {
    _restTimer?.cancel();
    setState(() {
      _accumulatedReps += repsDone;
      _isResting = true;
      _restSecondsRemaining = _currentRestDuration;
    });
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        timer.cancel();
        _finishRest();
      }
    });
  }

  void _finishRest() {
    _resetProvider();
    setState(() {
      _currentSet++;
      _isResting = false;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _finishRest();
  }

  void _completeWorkout(int repsDone) {
    setState(() {
      _accumulatedReps += repsDone;
    });
    
    if (_isProgramMode) {
      _programResults.add(ProgramExerciseResult(
        exerciseType: _currentExerciseType.name,
        totalReps: _accumulatedReps,
        targetReps: (_isProgramMode ? widget.program![_currentProgramIndex].targetReps : widget.targetReps),
        targetSets: (_isProgramMode ? widget.program![_currentProgramIndex].targetSets : widget.targetSets),
      ));
      
      if (_currentProgramIndex < widget.program!.length - 1) {
        _startTransition();
      } else {
        _finishAllWorkout();
      }
    } else {
      _finishAllWorkout();
    }
  }

  void _startTransition() {
    _restTimer?.cancel();
    setState(() {
      _isTransitioning = true;
      _transitionSecondsRemaining = widget.transitionRest ?? 60;
    });
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_transitionSecondsRemaining > 0) {
        setState(() {
          _transitionSecondsRemaining--;
        });
      } else {
        timer.cancel();
        _finishTransition();
      }
    });
  }

  void _finishTransition() {
    setState(() {
      _isTransitioning = false;
      _currentProgramIndex++;
      _currentSet = 1;
      _accumulatedReps = 0;
    });
    _resetProvider();
  }

  void _skipTransition() {
    _restTimer?.cancel();
    _finishTransition();
  }

  void _finishAllWorkout() {
    setState(() {
      _isWorkoutComplete = true;
    });
    _showWorkoutCompleteDialog();
  }

  void _showWorkoutCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD95C27), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD95C27).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'LATIHAN SELESAI!',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: const Color(0xFFD95C27),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kerja bagus! Anda telah menyelesaikan semua set latihan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('TOTAL SET', '${(_isProgramMode ? widget.program![_currentProgramIndex].targetSets : widget.targetSets)}', theme),
                    _buildStatItem('TOTAL REPS', '$_accumulatedReps', theme),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      if (_isProgramMode) {
                        Navigator.pop(this.context, _programResults);
                      } else {
                        Navigator.pop(this.context, _accumulatedReps);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD95C27),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'SIMPAN & KELUAR',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontSize: 32,
          ),
        ),
      ],
    );
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
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.select<LegRaiseProvider, String>((p) => p.status);
    }
  }

  int _getReps(BuildContext context) {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.select<LegRaiseProvider, int>((p) => p.repCount);
    }
  }

  double _getAngle(BuildContext context) {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.select<LegRaiseProvider, double>((p) => p.hipAngle);
    }
  }

  bool _getIsGoodPosture(BuildContext context) {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.select<LegRaiseProvider, bool>((p) => p.isGoodPosture);
    }
  }

  Pose? _getCurrentPose(BuildContext context) {
    switch (_currentExerciseType) {
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
      case ExerciseType.legRaise:
        return context.select<LegRaiseProvider, Pose?>((p) => p.currentPose);
    }
  }

  double _getRom(BuildContext context) {
    switch (_currentExerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, double>((p) => p.romPercentage);
      case ExerciseType.sitUp: return context.select<SitUpProvider, double>((p) => p.romPercentage);
      case ExerciseType.pushUp: return context.select<PushUpProvider, double>((p) => p.romPercentage);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, double>((p) => p.romPercentage);
      case ExerciseType.lunges: return context.select<LungesProvider, double>((p) => p.romPercentage);
      case ExerciseType.burpees: return context.select<BurpeesProvider, double>((p) => p.romPercentage);
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, double>((p) => p.romPercentage);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, double>((p) => p.romPercentage);
      case ExerciseType.plank: return context.select<PlankProvider, double>((p) => p.romPercentage);
      case ExerciseType.legRaise: return context.select<LegRaiseProvider, double>((p) => p.romPercentage);
    }
  }
  
  String _getTempo(BuildContext context) {
    switch (_currentExerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, String>((p) => p.tempoStatus);
      case ExerciseType.sitUp: return context.select<SitUpProvider, String>((p) => p.tempoStatus);
      case ExerciseType.pushUp: return context.select<PushUpProvider, String>((p) => p.tempoStatus);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, String>((p) => p.tempoStatus);
      case ExerciseType.lunges: return context.select<LungesProvider, String>((p) => p.tempoStatus);
      case ExerciseType.burpees: return context.select<BurpeesProvider, String>((p) => p.tempoStatus);
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, String>((p) => p.tempoStatus);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, String>((p) => p.tempoStatus);
      case ExerciseType.plank: return context.select<PlankProvider, String>((p) => p.tempoStatus);
      case ExerciseType.legRaise: return context.select<LegRaiseProvider, String>((p) => p.tempoStatus);
    }
  }

  List<Offset> _getTrajectory(BuildContext context) {
    switch (_currentExerciseType) {
      case ExerciseType.squat: return context.select<SquatProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.sitUp: return context.select<SitUpProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.pushUp: return context.select<PushUpProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.shoulderTap: return context.select<ShoulderTapProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.lunges: return context.select<LungesProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.burpees: return context.select<BurpeesProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.jumpingJack: return context.select<JumpingJackProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.benchDips: return context.select<BenchDipsProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.plank: return context.select<PlankProvider, List<Offset>>((p) => p.trajectoryPoints);
      case ExerciseType.legRaise: return context.select<LegRaiseProvider, List<Offset>>((p) => p.trajectoryPoints);
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
        title: Text("${_currentExerciseType.label} Counter"),
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
                  if (_isProgramMode) {
                    Navigator.pop(context, _programResults);
                  } else {
                    Navigator.pop(context, _accumulatedReps + _getRepCount());
                  }
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
          ),
          if (_isTransitioning)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.change_circle, color: Colors.blueAccent, size: 80),
                      const SizedBox(height: 20),
                      Text(
                        'PERSIAPKAN GERAKAN BERIKUTNYA',
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.program![_currentProgramIndex + 1].type.label,
                        style: GoogleFonts.bebasNeue(color: Colors.blueAccent, fontSize: 48),
                      ),
                      const SizedBox(height: 30),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _transitionSecondsRemaining / (widget.transitionRest ?? 60),
                              strokeWidth: 8,
                              backgroundColor: Colors.white10,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Text(
                            '$_transitionSecondsRemaining',
                            style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 48),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      TextButton.icon(
                        onPressed: _skipTransition,
                        icon: const Icon(Icons.skip_next, color: Colors.blueAccent),
                        label: Text('MULAI SEKARANG', style: GoogleFonts.bebasNeue(color: Colors.blueAccent, fontSize: 20)),
                        style: TextButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          if (_isResting && !_isTransitioning)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD95C27).withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hourglass_empty,
                          color: Color(0xFFD95C27),
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ISTIRAHAT SEJENAK',
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 32,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set $_currentSet Selesai! Tarik napas dalam-dalam.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: _restSecondsRemaining / _currentRestDuration,
                                strokeWidth: 8,
                                backgroundColor: Colors.white10,
                                color: const Color(0xFFD95C27),
                              ),
                            ),
                            Text(
                              '$_restSecondsRemaining',
                              style: GoogleFonts.bebasNeue(
                                color: Colors.white,
                                fontSize: 48,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Bersiap untuk Set ${_currentSet + 1}',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _skipRest,
                          icon: const Icon(Icons.skip_next, color: Color(0xFFD95C27)),
                          label: Text(
                            'LEWATI ISTIRAHAT',
                            style: GoogleFonts.bebasNeue(
                              color: const Color(0xFFD95C27),
                              fontSize: 18,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            side: const BorderSide(color: Color(0xFFD95C27), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayUI(String status, int reps, double angle, bool isGoodPosture, double rom, String tempo) {
    final hasTarget = (_isProgramMode ? widget.program![_currentProgramIndex].targetReps : widget.targetReps) > 0;
    
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
          if (hasTarget) ...[
            Text(
              "Set: $_currentSet / ${(_isProgramMode ? widget.program![_currentProgramIndex].targetSets : widget.targetSets)}",
              style: const TextStyle(color: Color(0xFFD95C27), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _currentExerciseType == ExerciseType.plank 
                ? "Waktu: $reps dtk" 
                : (hasTarget ? "Reps: $reps / ${(_isProgramMode ? widget.program![_currentProgramIndex].targetReps : widget.targetReps)}" : "Reps: $reps"), 
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
            "${_currentExerciseType.angleLabel}: ${angle.toStringAsFixed(0)}°", 
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


