import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/video_frame_extractor.dart';
import '../../core/analysis/video_form_analyzer.dart';
import '../../services/pose_inference_service.dart';
import '../../core/constants/exercise_type.dart';

class VideoFormCheckerScreen extends StatefulWidget {
  final bool isActive;
  const VideoFormCheckerScreen({super.key, this.isActive = true});

  @override
  State<VideoFormCheckerScreen> createState() => _VideoFormCheckerScreenState();
}

class _VideoFormCheckerScreenState extends State<VideoFormCheckerScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;

  bool _isAnalyzing = false;
  bool _isTrimming = false;
  VideoAnalysisResult? _result;
  String? _videoPath;
  ExerciseType _selectedExercise = ExerciseType.pushUp;
  double _videoDuration = 0.0;
  RangeValues _trimRange = const RangeValues(0, 0);
  late PoseInferenceService _poseService;
  late VideoFormAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _poseService = PoseInferenceService();
    _analyzer = VideoFormAnalyzer(_poseService);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoFormCheckerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      if (_videoController != null && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(video.path));
    await _videoController!.initialize();

    setState(() {
      _videoPath = video.path;
      _videoDuration = _videoController!.value.duration.inMilliseconds / 1000.0;
      _trimRange = RangeValues(0, _videoDuration);
      _isTrimming = true;
      _result = null;
    });

    _videoController!.addListener(() {
      if (_isTrimming &&
          _videoController != null &&
          _videoController!.value.isPlaying) {
        final currentPosition = _videoController!.value.position.inMilliseconds;
        final endPosition = (_trimRange.end * 1000).toInt();

        // Tolerance of 50ms to ensure it seeks back cleanly
        if (currentPosition >= endPosition - 50) {
          _videoController!.seekTo(
            Duration(milliseconds: (_trimRange.start * 1000).toInt()),
          );
        }
      }
    });

    _videoController!.setLooping(true);
    _videoController!.play();
  }

  Future<void> _analyzeVideo() async {
    if (_videoPath == null) return;

    setState(() {
      _isAnalyzing = true;
      _isTrimming = false;
    });

    try {
      // 0. Trim the video first
      final trimmedVideoPath = await VideoFrameExtractor.trimVideo(
        _videoPath!,
        _trimRange.start,
        _trimRange.end,
      );

      if (trimmedVideoPath == null) {
        throw Exception("Gagal memotong video");
      }

      // 1. Extract frames from the trimmed video
      final frames = await VideoFrameExtractor.extractFrames(
        trimmedVideoPath,
        fps:
            30, // Ditingkatkan ke 15 FPS agar tidak "melompat" frame terpenting di ujung gerakan
      );

      if (frames != null && frames.isNotEmpty) {
        // 2. Analyze frames
        final result = await _analyzer.analyzeFrames(frames, _selectedExercise);

        // 3. Cleanup temp frames
        await VideoFrameExtractor.cleanupFrames(frames);

        // 4. Update video controller to play the trimmed video
        _videoPath = trimmedVideoPath;
        if (mounted) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(File(trimmedVideoPath));
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.play();

          setState(() {
            _result = result;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal mengekstrak frame dari video. Pastikan format video didukung.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Widget _buildTrimmerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'POTONG VIDEO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (_videoController != null && _videoController!.value.isInitialized)
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoPlayer(_videoController!),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Geser slider untuk memilih bagian yang akan dinilai:',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          RangeSlider(
            values: _trimRange,
            min: 0.0,
            max: _videoDuration > 0 ? _videoDuration : 1.0,
            divisions: _videoDuration > 0 ? (_videoDuration * 10).toInt() : 1,
            labels: RangeLabels(
              '${_trimRange.start.toStringAsFixed(1)}s',
              '${_trimRange.end.toStringAsFixed(1)}s',
            ),
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white24,
            onChanged: (RangeValues values) {
              setState(() {
                _trimRange = values;
              });
              _videoController!.seekTo(
                Duration(milliseconds: (values.start * 1000).toInt()),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_trimRange.start.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                '${_trimRange.end.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _analyzeVideo,
            icon: const Icon(Icons.analytics),
            label: const Text(
              'ANALISIS BAGIAN INI',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_result == null) return const SizedBox.shrink();

    final Color scoreColor = _result!.score >= 80
        ? Colors.green
        : (_result!.score >= 60 ? Colors.orange : Colors.red);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_videoController != null && _videoController!.value.isInitialized)
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoPlayer(_videoController!),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'SKOR FORM ANDA',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      color: Colors.white70,
                      fontSize: 20,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_result!.score}%',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      color: scoreColor,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _result!.feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Divider(color: Colors.white24, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('REPETISI', '${_result!.totalReps}'),
                      _buildStatColumn(
                        'ROM TERTINGGI',
                        '${_result!.maxRom.toStringAsFixed(1)}%',
                      ),
                      _buildStatColumn(
                        'DURASI',
                        '${(_result!.totalFrames / 15).toStringAsFixed(1)}s',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _result = null;
                _videoController?.dispose();
                _videoController = null;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text(
              'ANALISIS VIDEO LAIN',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cek Video Form',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _isAnalyzing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 24),
                  Text(
                    'Sedang menganalisis gerakan...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Proses ini membutuhkan waktu beberapa saat',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          : (_isTrimming
                ? _buildTrimmerView()
                : (_result != null
                      ? _buildResultView()
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.video_file,
                                  size: 100,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Analisis Form dari Video',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Pilih video dari galeri Anda. AI kami akan mengekstrak frame dan menilai seberapa baik postur dan rentang gerakan Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<ExerciseType>(
                                      value: _selectedExercise,
                                      dropdownColor: const Color(0xFF2C2C2C),
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onChanged: (ExerciseType? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedExercise = newValue;
                                          });
                                        }
                                      },
                                      items: ExerciseType.values
                                          .map<DropdownMenuItem<ExerciseType>>((
                                            ExerciseType value,
                                          ) {
                                            return DropdownMenuItem<
                                              ExerciseType
                                            >(
                                              value: value,
                                              child: Text(
                                                'Gerakan: ${value.label}',
                                              ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _pickVideo,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text(
                                    'PILIH VIDEO',
                                    style: TextStyle(
                                      fontFamily: 'BebasNeue',
                                      fontSize: 20,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))),
    );
  }
}
