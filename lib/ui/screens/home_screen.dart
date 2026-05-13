import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/constants/exercise_type.dart';
import '../../data/local/hive_service.dart';
import '../../models/workout_session.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkoutSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _sessions = HiveService.getAllSessions();
    });
  }

  ExerciseType _typeFromString(String type) {
    switch (type) {
      case 'sitUp':
        return ExerciseType.sitUp;
      case 'pushUp':
        return ExerciseType.pushUp;
      default:
        return ExerciseType.squat;
    }
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Latihan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...ExerciseType.values.map((type) => ListTile(
                  leading: Icon(type.icon, size: 32, color: Colors.blue),
                  title: Text(type.label, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(_exerciseDescription(type)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _startExercise(type);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  String _exerciseDescription(ExerciseType type) {
    switch (type) {
      case ExerciseType.squat:
        return 'Latihan kaki — berdiri lalu jongkok';
      case ExerciseType.sitUp:
        return 'Latihan perut — rebahan lalu bangun';
      case ExerciseType.pushUp:
        return 'Latihan dada — push-up naik turun';
    }
  }

  Future<void> _startExercise(ExerciseType type) async {
    final startTime = DateTime.now();
    final reps = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          cameras: widget.cameras,
          exerciseType: type,
        ),
      ),
    );

    if (reps != null && reps > 0) {
      final duration = DateTime.now().difference(startTime).inSeconds;
      final session = WorkoutSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalReps: reps,
        durationSeconds: duration,
        exerciseType: type.name,
      );
      await HiveService.saveSession(session);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logbook Latihan')),
      body: _sessions.isEmpty
          ? const Center(child: Text("Belum ada riwayat latihan."))
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final exerciseType = _typeFromString(session.exerciseType);
                return ListTile(
                  leading: Icon(exerciseType.icon),
                  title: Text("${exerciseType.label} - ${session.totalReps} Reps"),
                  subtitle: Text(session.date.toLocal().toString().split('.')[0]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExercisePicker,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai Latihan'),
      ),
    );
  }
}
