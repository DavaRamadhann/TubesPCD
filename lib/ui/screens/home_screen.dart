import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/constants/exercise_type.dart';
import '../../data/local/hive_service.dart';
import '../../models/workout_session.dart';
import '../../models/program_session.dart';
import 'camera_screen.dart';
import 'create_program_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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
            _startExercise(
              type,
              targetReps: reps,
              targetSets: sets,
              restDuration: rest,
            );
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
    final result = await Navigator.push(
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

    if (result != null && result is int && result > 0) {
      final reps = result;
      final duration = DateTime.now().difference(startTime).inSeconds;
      final session = WorkoutSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalReps: reps,
        durationSeconds: duration,
        exerciseType: type.name,
      );
      await HiveService.saveSession(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: const Color(0xFF1B1B1B),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD95C27), Color(0xFFFF8A50)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'CALYSC',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 2.0,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),

          // ── Focus Area Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD95C27),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FOCUS AREA',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Focus Area Grid ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final type = ExerciseType.values[index];
                  return _ExerciseCard(
                    exerciseType: type,
                    onTap: () => _showWorkoutConfig(type),
                  );
                },
                childCount: ExerciseType.values.length,
              ),
            ),
          ),

          // ── Bottom Spacing ──
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),

      // ── FAB: Buat Program ──
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "btn_program",
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => CreateProgramScreen(cameras: widget.cameras))
          );
          if (result != null && result is List<ProgramExerciseResult>) {
            final session = ProgramSession(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              date: DateTime.now(),
              name: "Program Custom",
              totalDurationSeconds: 0,
              exercises: result,
            );
            await HiveService.saveProgramSession(session);
          }
        },
        icon: const Icon(Icons.list_alt),
        label: const Text(
          'BUAT PROGRAM',
          style: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFFD95C27),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Exercise Card — Focus Area Grid Item
// ═══════════════════════════════════════════════════
class _ExerciseCard extends StatelessWidget {
  final ExerciseType exerciseType;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exerciseType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white24,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: exerciseType.gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: exerciseType.gradientColors.first.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background icon (large, faded)
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  exerciseType.icon,
                  size: 80,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        exerciseType.icon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      exerciseType.label.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'BebasNeue',
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════
//  Workout Config Bottom Sheet (unchanged logic)
// ═══════════════════════════════════════════════════
class _WorkoutConfigSheet extends StatefulWidget {
  final ExerciseType exerciseType;
  final Function(int reps, int sets, int rest) onStart;

  const _WorkoutConfigSheet({
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
              Icon(
                widget.exerciseType.icon,
                size: 36,
                color: const Color(0xFFD95C27),
              ),
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
              ),
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
                    setState(
                      () => _reps = isPlank
                          ? (_reps - 5 < 5 ? 5 : _reps - 5)
                          : _reps - 1,
                    );
                  }
                },
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() => _reps = isPlank ? _reps + 5 : _reps + 1);
                },
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
                },
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() => _sets++);
                },
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
                },
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() => _rest += 5);
                },
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

  Widget _buildAdjustButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
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
