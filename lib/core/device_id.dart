import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install identifier used to key this device's push tokens on the
/// backend (so a user can be reached on ALL of their devices, not just the last
/// one that logged in). Generated once and persisted; also cached in memory so
/// it can be read synchronously where an await isn't possible (socket connect).
class DeviceId {
  DeviceId._();

  static const _key = '@device_id';
  static String? _cached;

  /// The cached id, or empty string if [ensure] hasn't completed yet.
  static String get value => _cached ?? '';

  /// Load the stored id (generating + persisting one on first run) and cache it.
  /// Call once early in app startup.
  static Future<String> ensure() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
