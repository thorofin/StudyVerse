import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyId   = 'user_id';
  static const _keyName = 'user_name';

  // Retourne la session sauvegardée
  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id    = prefs.getString(_keyId);
    final name  = prefs.getString(_keyName);
    if (id == null || name == null) return null;
    return {'id': id, 'name': name};
  }

  // Sauvegarde la session
  static Future<void> saveSession(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId,   id);
    await prefs.setString(_keyName, name);
  }

  // Supprime la session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
  }
}