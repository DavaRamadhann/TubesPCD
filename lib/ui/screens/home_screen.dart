import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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
                return ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text("Squat - ${session.totalReps} Reps"),
                  subtitle: Text(session.date.toLocal().toString().split('.')[0]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final startTime = DateTime.now();
          final reps = await Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (_) => CameraScreen(cameras: widget.cameras),
            ),
          );

          if (reps != null && reps > 0) {
            final duration = DateTime.now().difference(startTime).inSeconds;
            final session = WorkoutSession(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              date: DateTime.now(),
              totalReps: reps,
              durationSeconds: duration,
            );
            await HiveService.saveSession(session);
            _loadSessions();
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai Latihan'),
      ),
    );
  }
}
