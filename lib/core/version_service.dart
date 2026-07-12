import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'storage.dart';

/// VersionService — mirrors RN src/lib/VersionService.ts
///
/// On each app startup, compares the running version to the last-stored version.
/// If they differ (i.e. the app was upgraded) the auth token is cleared so the
/// user is forced to log in again with the new version.  The new version is
/// then persisted so subsequent cold-starts don't trigger another logout.
///
/// Call [VersionService.checkAndHandle] once during startup (after bindings,
/// before or in ProviderScope first-frame).  It is fully guarded — any error
/// is printed and swallowed so a failure never blocks startup.
class VersionService {
  VersionService._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _versionKey = 'app_version';

  /// Human-readable running version for display (e.g. "2.0.4 (23)"). Reads the
  /// real bundle version at runtime, so it auto-updates with every release.
  static Future<String> displayVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version} (${info.buildNumber})';
    } catch (_) {
      return '';
    }
  }

  /// Returns the last version string we stored (null if first install).
  static Future<String?> _storedVersion() async {
    try {
      return await _secureStorage.read(key: _versionKey);
    } catch (_) {
      return null;
    }
  }

  /// Persists [version] to secure storage.
  static Future<void> _saveVersion(String version) async {
    try {
      await _secureStorage.write(key: _versionKey, value: version);
    } catch (e) {
      debugPrint('[VersionService] saveVersion error: $e');
    }
  }

  /// Main entry point.  Call once after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> checkAndHandle() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Use versionName (build-name) e.g. "1.0.0"
      final current = info.version;

      final stored = await _storedVersion();

      if (stored == null) {
        // First install — just store the version, no token to clear.
        debugPrint('[VersionService] First install, storing version $current');
        await _saveVersion(current);
        return;
      }

      if (stored != current) {
        // App was upgraded — force re-login by clearing auth.
        debugPrint(
          '[VersionService] App upgraded $stored → $current, clearing auth',
        );
        await AppStorage.clearAuth();
        await _saveVersion(current);
      } else {
        debugPrint('[VersionService] Version unchanged ($current)');
      }
    } catch (e) {
      debugPrint('[VersionService] checkAndHandle error (non-fatal): $e');
    }
  }
}
