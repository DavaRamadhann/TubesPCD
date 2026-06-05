import 'package:flutter/material.dart';

import '../../core/constants/exercise_type.dart';
import '../../data/local/hive_service.dart';
import '../../models/workout_session.dart';
import '../../models/program_session.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _allSessions = [];
  String _selectedFilter = 'Semua';

  final List<String> _filters = [
    'Semua',
    'Latihan Tunggal',
    'Program',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      final singleSessions = HiveService.getAllSessions();
      final programSessions = HiveService.getAllProgramSessions();

      _allSessions = [...singleSessions, ...programSessions];
      _allSessions.sort(
          (a, b) => (b.date as DateTime).compareTo(a.date as DateTime));
    });
  }

  List<dynamic> get _filteredSessions {
    if (_selectedFilter == 'Latihan Tunggal') {
      return _allSessions.whereType<WorkoutSession>().toList();
    } else if (_selectedFilter == 'Program') {
      return _allSessions.whereType<ProgramSession>().toList();
    }
    return _allSessions;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(sessionDate).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // Group sessions by date
  Map<String, List<dynamic>> _groupByDate(List<dynamic> sessions) {
    final Map<String, List<dynamic>> grouped = {};
    for (final session in sessions) {
      final date = session.date as DateTime;
      final key = _formatDate(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(session);
    }
    return grouped;
  }

  // Stats
  int get _totalWorkouts => _allSessions.length;
  int get _totalReps {
    int total = 0;
    for (final s in _allSessions) {
      if (s is WorkoutSession) {
        total += s.totalReps;
      } else if (s is ProgramSession) {
        for (final e in s.exercises) {
          total += e.totalReps;
        }
      }
    }
    return total;
  }

  int get _thisWeekWorkouts {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _allSessions.where((s) {
      final date = s.date as DateTime;
      return date.isAfter(startOfWeek);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredSessions;
    final grouped = _groupByDate(filtered);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: const Color(0xFF1B1B1B),
            elevation: 0,
            title: Text(
              'RIWAYAT LATIHAN',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 2.0,
                fontSize: 24,
              ),
            ),
          ),

          // ── Stats Summary Cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _StatCard(
                    icon: Icons.fitness_center,
                    value: '$_totalWorkouts',
                    label: 'Total Sesi',
                    gradient: const [Color(0xFFD95C27), Color(0xFFFF8A50)],
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.repeat,
                    value: _totalReps > 999
                        ? '${(_totalReps / 1000).toStringAsFixed(1)}k'
                        : '$_totalReps',
                    label: 'Total Reps',
                    gradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.calendar_today,
                    value: '$_thisWeekWorkouts',
                    label: 'Minggu Ini',
                    gradient: const [Color(0xFF059669), Color(0xFF34D399)],
                  ),
                ],
              ),
            ),
          ),

          // ── Filter Chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(colors: [
                                  Color(0xFFD95C27),
                                  Color(0xFFFF8A50),
                                ])
                              : null,
                          color: isSelected ? null : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white12,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Empty State ──
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada riwayat',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white30,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mulai latihan untuk melihat riwayat di sini',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // ── Grouped Session List ──
            ...grouped.entries.map((entry) {
              final dateLabel = entry.key;
              final sessions = entry.value;
              return SliverMainAxisGroup(
                slivers: [
                  // Date Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dateLabel,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Session Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = sessions[index];
                          if (session is ProgramSession) {
                            return _ProgramHistoryCard(
                              session: session,
                              formatTime: _formatTime,
                            );
                          } else if (session is WorkoutSession) {
                            final type =
                                _typeFromString(session.exerciseType);
                            return _WorkoutHistoryCard(
                              session: session,
                              exerciseType: type,
                              formatTime: _formatTime,
                              formatDuration: _formatDuration,
                            );
                          }
                          return const SizedBox();
                        },
                        childCount: sessions.length,
                      ),
                    ),
                  ),
                ],
              );
            }),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Stat Card Widget
// ═══════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradient[0].withValues(alpha: 0.2),
              gradient[1].withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient[0].withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: gradient[1], size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: gradient[1],
                fontFamily: 'BebasNeue',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Workout History Card (Single Exercise)
// ═══════════════════════════════════════════════════
class _WorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession session;
  final ExerciseType exerciseType;
  final String Function(DateTime) formatTime;
  final String Function(int) formatDuration;

  const _WorkoutHistoryCard({
    required this.session,
    required this.exerciseType,
    required this.formatTime,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final isPlank = exerciseType == ExerciseType.plank;
    final valueText =
        isPlank ? '${session.totalReps} Detik' : '${session.totalReps} Reps';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Exercise icon with gradient
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: exerciseType.gradientColors,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(exerciseType.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseType.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(session.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (session.durationSeconds > 0) ...[
                      Icon(Icons.timer_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(width: 4),
                      Text(
                        formatDuration(session.durationSeconds),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Reps badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  exerciseType.gradientColors[0].withValues(alpha: 0.25),
                  exerciseType.gradientColors[1].withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              valueText,
              style: TextStyle(
                color: exerciseType.gradientColors[1],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Program History Card
// ═══════════════════════════════════════════════════
class _ProgramHistoryCard extends StatelessWidget {
  final ProgramSession session;
  final String Function(DateTime) formatTime;

  const _ProgramHistoryCard({
    required this.session,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF1E3456)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 14, right: 14, bottom: 12),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.playlist_play,
                color: Colors.white, size: 26),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  session.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Icon(Icons.access_time,
                  size: 13, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              Text(
                formatTime(session.date),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${session.exercises.length} Gerakan',
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: session.exercises.map((e) {
            final isPlank = e.exerciseType.toLowerCase() == 'plank';
            final targetText = isPlank
                ? '${e.targetSets}S × ${e.targetReps} Detik'
                : '${e.targetSets}S × ${e.targetReps} Reps';
            final totalText =
                isPlank ? '${e.totalReps} Detik' : '${e.totalReps} Reps';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.exerciseType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: $targetText',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      totalText,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
