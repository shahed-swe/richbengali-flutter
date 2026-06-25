import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const _tokenKey      = 'auth_token';
  static const _prefTokenKey  = '@auth_token';
  static const _prefUserKey   = '@user';

  // ---------- Auth save ----------
  static Future<void> saveAuth(String token, String userJson) async {
    await Future.wait([
      _secureStorage.write(key: _tokenKey, value: token),
      _savePrefs(token, userJson),
    ]);
  }

  static Future<void> _savePrefs(String token, String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_prefTokenKey, token),
      prefs.setString(_prefUserKey, userJson),
    ]);
  }

  // ---------- Token ----------
  static Future<String?> getToken() async {
    // Try secure storage first
    try {
      final t = await _secureStorage.read(key: _tokenKey);
      if (t != null) return t;
    } catch (_) {}
    // Fallback to shared prefs (background task contexts)
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefTokenKey);
  }

  static Future<void> saveToken(String token) async {
    await Future.wait([
      _secureStorage.write(key: _tokenKey, value: token),
      SharedPreferences.getInstance()
          .then((p) => p.setString(_prefTokenKey, token)),
    ]);
  }

  // ---------- User ----------
  static Future<void> saveUser(String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserKey, userJson);
  }

  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefUserKey);
  }

  // ---------- Clear ----------
  static Future<void> clearAuth() async {
    await Future.wait([
      _secureStorage.delete(key: _tokenKey),
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.remove(_prefTokenKey);
        await prefs.remove(_prefUserKey);
      }),
    ]);
  }
}
