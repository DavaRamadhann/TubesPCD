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
      case 'shoulderTap':
        return ExerciseType.shoulderTap;
      case 'lunges':
        return ExerciseType.lunges;
      case 'burpees':
        return ExerciseType.burpees;
      case 'jumpingJack':
        return ExerciseType.jumpingJack;
      case 'benchDips':
        return ExerciseType.benchDips;
      case 'plank':
        return ExerciseType.plank;
      case 'legRaise':
        return ExerciseType.legRaise;
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Pilih Latihan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: ExerciseType.values.map((type) => ListTile(
                      leading: Icon(type.icon, size: 32, color: Colors.blue),
                      title: Text(type.label, style: const TextStyle(fontSize: 18)),
                      subtitle: Text(_exerciseDescription(type)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showWorkoutConfig(type);
                      },
                    )).toList(),
                  ),
                ),
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
      case ExerciseType.shoulderTap:
        return 'Latihan bahu — tap bahu kanan-kiri bergantian';
      case ExerciseType.lunges:
        return 'Latihan kaki — melangkah dan turunkan pinggul bergantian kaki';
      case ExerciseType.burpees:
        return 'Latihan seluruh tubuh — turun plank lalu loncat berdiri';
      case ExerciseType.jumpingJack:
        return 'Latihan kardio — buka tutup kaki dan angkat tangan';
      case ExerciseType.benchDips:
        return 'Latihan tricep — duduk di bangku, turun naikkan badan';
      case ExerciseType.plank:
        return 'Latihan inti — tahan posisi badan lurus statis';
      case ExerciseType.legRaise:
        return 'Latihan perut — rebahan dan angkat lurus kedua kaki';
    }
  }

  void _showWorkoutConfig(ExerciseType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return _WorkoutConfigSheet(
          exerciseType: type,
          onStart: (reps, sets, rest) {
            Navigator.pop(context);
            _startExercise(type, targetReps: reps, targetSets: sets, restDuration: rest);
          },
        );
      },
    );
  }

  Future<void> _startExercise(
    ExerciseType type, {
    required int targetReps,
    required int targetSets,
    required int restDuration,
  }) async {
    final startTime = DateTime.now();
    final reps = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          cameras: widget.cameras,
          exerciseType: type,
          targetReps: targetReps,
          targetSets: targetSets,
          restDuration: restDuration,
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logbook Latihan',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Text(
                "Belum ada riwayat latihan.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final exerciseType = _typeFromString(session.exerciseType);
                return Card(
                  color: const Color(0xFF2C2C2C),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(exerciseType.icon, color: theme.colorScheme.primary),
                    title: Text(
                      exerciseType == ExerciseType.plank 
                          ? "${exerciseType.label} - ${session.totalReps} Detik"
                          : "${exerciseType.label} - ${session.totalReps} Reps",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      session.date.toLocal().toString().split('.')[0],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExercisePicker,
        icon: const Icon(Icons.play_arrow),
        label: const Text(
          'MULAI LATIHAN',
          style: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 1.2),
        ),
      ),
    );
  }
}

class _WorkoutConfigSheet extends StatefulWidget {
  final ExerciseType exerciseType;
  final Function(int reps, int sets, int rest) onStart;

  const _WorkoutConfigSheet({
    super.key,
    required this.exerciseType,
    required this.onStart,
  });

  @override
  State<_WorkoutConfigSheet> createState() => _WorkoutConfigSheetState();
}

class _WorkoutConfigSheetState extends State<_WorkoutConfigSheet> {
  late int _reps;
  int _sets = 3;
  int _rest = 30;

  @override
  void initState() {
    super.initState();
    _reps = widget.exerciseType == ExerciseType.plank ? 30 : 10;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlank = widget.exerciseType == ExerciseType.plank;
    
    final quickRepsOptions = isPlank ? [20, 30, 45, 60] : [8, 10, 12, 15];
    final quickSetsOptions = [1, 2, 3, 4, 5];
    final quickRestOptions = [15, 30, 45, 60];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(widget.exerciseType.icon, size: 36, color: const Color(0xFFD95C27)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KONFIGURASI LATIHAN',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      widget.exerciseType.label.toUpperCase(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          
          // Reps Selector
          Text(
            isPlank ? 'TARGET DURASI SET (DETIK)' : 'TARGET REPETISI PER SET',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdjustButton(
                icon: Icons.remove, 
                onPressed: () {
                  if (_reps > 1) {
                    setState(() => _reps = isPlank ? (_reps - 5 < 5 ? 5 : _reps - 5) : _reps - 1);
                  }
                }
              ),
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_reps ${isPlank ? "detik" : "reps"}',
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add, 
                onPressed: () {
                  setState(() => _reps = isPlank ? _reps + 5 : _reps + 1);
                }
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: quickRepsOptions.map((opt) {
              final isSelected = _reps == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text('$opt${isPlank ? "s" : ""}'),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD95C27),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _reps = opt);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
          
          // Sets Selector
          Text(
            'TARGET JUMLAH SET',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdjustButton(
                icon: Icons.remove, 
                onPressed: () {
                  if (_sets > 1) {
                    setState(() => _sets--);
                  }
                }
              ),
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_sets set',
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add, 
                onPressed: () {
                  setState(() => _sets++);
                }
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: quickSetsOptions.map((opt) {
              final isSelected = _sets == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text('$opt set'),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD95C27),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _sets = opt);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Rest Selector
          Text(
            'DURASI ISTIRAHAT ANTAR SET (DETIK)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdjustButton(
                icon: Icons.remove, 
                onPressed: () {
                  if (_rest > 5) {
                    setState(() => _rest -= 5);
                  }
                }
              ),
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_rest detik',
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add, 
                onPressed: () {
                  setState(() => _rest += 5);
                }
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: quickRestOptions.map((opt) {
              final isSelected = _rest == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text('${opt}s'),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD95C27),
                    backgroundColor: Colors.white12,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _rest = opt);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onStart(_reps, _sets, _rest),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD95C27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'MULAI LATIHAN',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.5,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
