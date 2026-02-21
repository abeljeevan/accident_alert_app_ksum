import 'package:shared_preferences/shared_preferences.dart';

class AccidentLogStore {
  static List<String> logs = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    logs = prefs.getStringList('accident_logs') ?? [];
  }

  static Future<void> add(String log) async {
    logs.insert(0, log);
    await save();
  }

  static Future<void> clear() async {
    logs.clear();
    await save();
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('accident_logs', logs);
  }
}