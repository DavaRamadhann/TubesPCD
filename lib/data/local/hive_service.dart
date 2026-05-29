import 'package:hive_flutter/hive_flutter.dart';
import '../../models/workout_session.dart';
import '../../models/program_session.dart';

class HiveService {
  static const String boxName = 'workout_box';
  static const String programBoxName = 'program_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(WorkoutSessionAdapter());
    Hive.registerAdapter(ProgramSessionAdapter());
    Hive.registerAdapter(ProgramExerciseResultAdapter());
    await Hive.openBox<WorkoutSession>(boxName);
    await Hive.openBox<ProgramSession>(programBoxName);
  }

  static Box<WorkoutSession> getBox() {
    return Hive.box<WorkoutSession>(boxName);
  }

  static Box<ProgramSession> getProgramBox() {
    return Hive.box<ProgramSession>(programBoxName);
  }

  static Future<void> saveSession(WorkoutSession session) async {
    final box = getBox();
    await box.put(session.id, session);
  }

  static Future<void> saveProgramSession(ProgramSession session) async {
    final box = getProgramBox();
    await box.put(session.id, session);
  }

  static List<WorkoutSession> getAllSessions() {
    final box = getBox();
    final list = box.values.cast<WorkoutSession>().toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // Descending
    return list;
  }

  static List<ProgramSession> getAllProgramSessions() {
    final box = getProgramBox();
    final list = box.values.cast<ProgramSession>().toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // Descending
    return list;
  }
}
