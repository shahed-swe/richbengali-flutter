import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deep-links to the OEM settings that Android gives no API for.
///
/// Chinese-OEM skins (Xiaomi/MIUI+HyperOS, Oppo/Realme ColorOS, Vivo, Huawei,
/// Transsion) kill backgrounded apps and block background window starts. Two of
/// those settings CANNOT be granted programmatically or requested with a normal
/// permission dialog, and without them the app looks broken:
///
///  • **Autostart** — the OEM kills the app shortly after it is backgrounded and
///    a killed app receives NO FCM at all, so neither messages nor calls arrive
///    once the app is closed.
///  • **"Display pop-up windows while running in background"** — blocks the
///    full-screen intent, so an incoming call can't ring full-screen. On
///    Android 14+ the CallStyle notification is then rejected outright
///    ("Not posted. CallStyle notifications must be for a foreground service …")
///    and no incoming-call UI appears at all.
///
/// All we can do is take the user straight to those screens.
class OemSetupService {
  OemSetupService._();

  static const _channel = MethodChannel('com.richbengali.oem');
  static const _doneKey = 'oem_call_setup_done_v1';

  /// Skins known to need the manual steps above.
  static const _aggressiveVendors = <String>{
    'xiaomi', 'redmi', 'poco',
    'oppo', 'realme', 'oneplus',
    'vivo', 'iqoo',
    'huawei', 'honor',
    'meizu', 'letv',
    // Transsion brands — very common in Bangladesh and very aggressive.
    'tecno', 'infinix', 'itel',
  };

  static String? _cachedManufacturer;

  static Future<String> manufacturer() async {
    if (!Platform.isAndroid) return '';
    if (_cachedManufacturer != null) return _cachedManufacturer!;
    try {
      final m = await _channel.invokeMethod<String>('getManufacturer');
      _cachedManufacturer = (m ?? '').toLowerCase();
    } catch (e) {
      debugPrint('[OemSetup] getManufacturer error: $e');
      _cachedManufacturer = '';
    }
    return _cachedManufacturer!;
  }

  /// True when this device needs the manual steps (and the user hasn't already
  /// been walked through them).
  static Future<bool> needsSetup() async {
    if (!Platform.isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) ?? false) return false;
    } catch (_) {}
    final m = await manufacturer();
    if (m.isEmpty) return false;
    return _aggressiveVendors.any(m.contains);
  }

  /// Remember that the user has been through the setup, so we don't nag.
  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_doneKey, true);
    } catch (e) {
      debugPrint('[OemSetup] markDone error: $e');
    }
  }

  static Future<bool> openAutostartSettings() =>
      _invoke('openAutostartSettings');

  static Future<bool> openBackgroundPopupSettings() =>
      _invoke('openBackgroundPopupSettings');

  static Future<bool> openBatterySettings() => _invoke('openBatterySettings');

  static Future<bool> _invoke(String method) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      debugPrint('[OemSetup] $method error: $e');
      return false;
    }
  }
}
