import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyId    = 'user_id';
  static const _keyName  = 'user_name';
  static const _keyEmail = 'user_email';

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id    = prefs.getString(_keyId);
    final name  = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);
    if (id == null || name == null) return null;
    return {'id': id, 'name': name, 'email': email ?? ''};
  }

  static Future<void> saveSession(
      String id, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId,    id);
    await prefs.setString(_keyName,  name);
    await prefs.setString(_keyEmail, email);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
  }
}