import 'package:hive_flutter/hive_flutter.dart';
import '../../models/workout_session.dart';

class HiveService {
  static const String boxName = 'workout_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(WorkoutSessionAdapter());
    await Hive.openBox<WorkoutSession>(boxName);
  }

  static Box<WorkoutSession> getBox() {
    return Hive.box<WorkoutSession>(boxName);
  }

  static Future<void> saveSession(WorkoutSession session) async {
    final box = getBox();
    await box.put(session.id, session);
  }

  static List<WorkoutSession> getAllSessions() {
    final box = getBox();
    final list = box.values.cast<WorkoutSession>().toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // Descending
    return list;
  }
}
