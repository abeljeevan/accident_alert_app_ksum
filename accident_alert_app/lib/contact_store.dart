import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContactsStore {
  static List<String> contacts = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    contacts = prefs.getStringList('emergency_contacts') ?? [];
  }

  static Future<void> add(String number) async {
    contacts.add(number);
    await save();
  }

  static Future<void> remove(String number) async {
    contacts.remove(number);
    await save();
  }

  static Future<void> clear() async {
    contacts.clear();
    await save();
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('emergency_contacts', contacts);
  }
}
