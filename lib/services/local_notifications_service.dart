import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// LocalNotificationsService — mirrors helper.ts displayLocalNotification
// and Notifee channel setup in VoipNotificationHandler.ts
// ---------------------------------------------------------------------------

/// Key used to stash the most-recent tapped notification payload so the
/// router can deep-link after the widget tree is ready.
const _kPendingNotifPayload = 'pending_notif_payload';

class LocalNotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Android channel IDs — match com.richbengali.app namespace
  static const _chatChannelId = 'com.richbengali.app.chat';
  static const _callChannelId = 'com.richbengali.app.calls';

  /// Must be called once before [runApp] (or during app start).
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      const chatChannel = AndroidNotificationChannel(
        _chatChannelId,
        'Messages',
        description: 'Chat message notifications',
        importance: Importance.high,
      );
      const callChannel = AndroidNotificationChannel(
        _callChannelId,
        'Incoming Calls',
        description: 'Incoming call alerts',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(callChannel);
    }

    debugPrint('[LocalNotif] Initialized');
  }

  // ---------------------------------------------------------------------------
  // Chat notification — mirrors helper.ts displayLocalNotification
  // ---------------------------------------------------------------------------

  static Future<void> showChatNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        'Messages',
        channelDescription: 'Chat message notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );
      await _plugin.show(
        // Use a stable ID so rapid chat messages collapse into one notif
        'chat-notification'.hashCode & 0x7FFFFFFF,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[LocalNotif] showChatNotification error: $e');
    }
  }

  /// Cancel all notifications (call when app is foregrounded — mirrors
  /// the App.tsx AppState change handler that clears badge/notifications).
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[LocalNotif] cancelAll error: $e');
    }
  }

  /// Cancel a specific notification by id.
  static Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[LocalNotif] cancel($id) error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Pending payload — allows router to deep-link after cold start
  // ---------------------------------------------------------------------------

  /// Persist payload when notification is tapped (background/terminated).
  static Future<void> _persistPayload(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingNotifPayload, payload);
    } catch (_) {}
  }

  /// Consume and clear the pending tapped-notification payload.
  static Future<String?> consumePendingPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_kPendingNotifPayload);
      if (val != null) await prefs.remove(_kPendingNotifPayload);
      return val;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Tap callbacks
  // ---------------------------------------------------------------------------

  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      debugPrint('[LocalNotif] Tapped (foreground): $payload');
      // Navigation is handled by the router once it checks consumePendingPayload
      _persistPayload(payload);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      debugPrint('[LocalNotif] Tapped (background/terminated): $payload');
      _persistPayload(payload);
    }
  }
}

// ---------------------------------------------------------------------------
// Provider (for injection where needed)
// ---------------------------------------------------------------------------

final localNotificationsServiceProvider =
    Provider<LocalNotificationsService>((_) => LocalNotificationsService());
