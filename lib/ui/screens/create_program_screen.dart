import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/constants/exercise_type.dart';
import '../../models/exercise_config.dart';
import '../../models/program_session.dart';
import 'camera_screen.dart';

class CreateProgramScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CreateProgramScreen({super.key, required this.cameras});

  @override
  State<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends State<CreateProgramScreen> {
  final List<ExerciseConfig> _programList = [];
  int _transitionRest = 60;
  final TextEditingController _nameController = TextEditingController(
    text: "Program Custom",
  );

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
                    children: ExerciseType.values
                        .map(
                          (type) => ListTile(
                            leading: Icon(
                              type.icon,
                              size: 32,
                              color: Colors.blue,
                            ),
                            title: Text(
                              type.label,
                              style: const TextStyle(fontSize: 18),
                            ),
                            subtitle: Text(_exerciseDescription(type)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              _showWorkoutConfig(type);
                            },
                          ),
                        )
                        .toList(),
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
        return _ProgramWorkoutConfigSheet(
          exerciseType: type,
          onAdd: (reps, sets, rest) {
            setState(() {
              _programList.add(
                ExerciseConfig(
                  type: type,
                  targetReps: reps,
                  targetSets: sets,
                  restDuration: rest,
                ),
              );
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _startProgram() async {
    if (_programList.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          cameras: widget.cameras,
          program: _programList,
          programName: _nameController.text,
          transitionRest: _transitionRest,
        ),
      ),
    );

    if (result != null && result is List<ProgramExerciseResult>) {
      if (mounted) {
        Navigator.pop(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Buat Program Latihan',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nama Program',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Jeda Transisi Antar Gerakan (detik):",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () => setState(
                    () => _transitionRest > 10 ? _transitionRest -= 10 : null,
                  ),
                ),
                Text(
                  '$_transitionRest',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => setState(() => _transitionRest += 10),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: _programList.isEmpty
                ? const Center(
                    child: Text(
                      "Belum ada gerakan ditambahkan.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _programList.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _programList.removeAt(oldIndex);
                        _programList.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final config = _programList[index];
                      return Card(
                        key: ValueKey(config.hashCode),
                        color: const Color(0xFF2C2C2C),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            config.type.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${config.targetSets} Set x ${config.targetReps} Reps (Rest: ${config.restDuration}s)',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _programList.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showExercisePicker,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'TAMBAH GERAKAN',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        letterSpacing: 1.2,
                        fontSize: 18,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _programList.isEmpty ? null : _startProgram,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'MULAI PROGRAM',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        letterSpacing: 1.2,
                        fontSize: 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramWorkoutConfigSheet extends StatefulWidget {
  final ExerciseType exerciseType;
  final Function(int reps, int sets, int rest) onAdd;

  const _ProgramWorkoutConfigSheet({
    required this.exerciseType,
    required this.onAdd,
  });

  @override
  State<_ProgramWorkoutConfigSheet> createState() =>
      _ProgramWorkoutConfigSheetState();
}

class _ProgramWorkoutConfigSheetState
    extends State<_ProgramWorkoutConfigSheet> {
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

          // Add Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onAdd(_reps, _sets, _rest),
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
                'TAMBAH KE PROGRAM',
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
