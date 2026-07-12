import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../state/auth_provider.dart';
import '../state/call_overlay_provider.dart';
import '../state/me_provider.dart';
import '../state/notifications_provider.dart';
import 'callkit_service.dart';
import 'local_notifications_service.dart';
import 'voip_push_service.dart';

// ---------------------------------------------------------------------------
// NOTE: Firebase imports are present but ALL calls are wrapped in try/catch.
//
// The google-services Gradle plugin is NOT applied (no google-services.json yet).
// Firebase will throw at runtime when unconfigured — we catch and log, so the
// app continues to function normally for all non-push features.
//
// TODO (Phase 8): After dropping google-services.json into android/app/ and
//   GoogleService-Info.plist into ios/Runner/, un-comment the google-services
//   plugin in android/app/build.gradle.kts and test on device.
// ---------------------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ---------------------------------------------------------------------------
// Background message handler — must be a top-level function.
// Mirrors index.js messaging().setBackgroundMessageHandler
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: initialise Firebase before using any Firebase APIs.
  // Guarded so a config issue never crashes the isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  try {
    debugPrint(
        '[FCM-BG] Received: ${message.messageId} type=${message.data['type']}');
    final type = message.data['type']?.toString();
    // Backend sends `callAction` for calls; accept `subType` too.
    final subType =
        (message.data['subType'] ?? message.data['callAction'])?.toString();

    if (type == 'call') {
      // Incoming call while the app is backgrounded/killed → show the native
      // CallKit ring UI. (On iOS the VoIP/PushKit path also covers this; on
      // Android this FCM handler is what makes background calls actually ring.)
      if (subType == null || subType == 'initiated') {
        await CallkitService.showIncomingFromPush(
          Map<String, dynamic>.from(message.data),
        );
      } else if (subType == 'ended' || subType == 'cancelled') {
        await CallkitService.endAllFromPush();
      }
    } else {
      // Chat / other — show a local notification.
      // Re-initialise LocalNotificationsService in this isolate.
      await LocalNotificationsService.init();
      final senderName = message.data['senderName']?.toString() ??
          message.notification?.title ??
          'New message';
      final body = message.data['body']?.toString() ??
          message.notification?.body ??
          '';
      // Backend sends `room_id` (snake_case); accept `roomId` too.
      final roomId =
          (message.data['roomId'] ?? message.data['room_id'] ?? '').toString();
      await LocalNotificationsService.showChatNotification(
        title: senderName,
        body: body,
        payload: 'chat:$roomId',
      );
    }
  } catch (e) {
    debugPrint('[FCM-BG] Handler error: $e');
  }
}

// ---------------------------------------------------------------------------
// PushService — mirrors usePushNotifications.ts + FCM parts of App.tsx / helper.ts
// ---------------------------------------------------------------------------

class PushService {
  PushService(this._ref);

  final Ref _ref;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // init — request permission + get FCM token
  // Mirrors usePushNotifications.ts requestPermission + getToken flow
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // --- Firebase init (guarded) ---
    // TODO: enable after adding google-services.json + applying google-services plugin
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      debugPrint('[Push] Firebase initialized');
    } catch (e) {
      debugPrint(
          '[Push] Firebase.initializeApp() failed '
          '(expected if google-services.json missing): $e');
    }

    if (!firebaseReady) {
      debugPrint('[Push] Skipping FCM setup — Firebase not configured');
      return;
    }

    // --- Request permission ---
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[Push] Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[Push] requestPermission error: $e');
    }

    // --- Get FCM token ---
    // Mirrors usePushNotifications.ts getToken with iOS retry logic
    await _acquireFcmToken();

    // --- Token refresh listener ---
    // Mirrors App.tsx messaging().onTokenRefresh
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('[Push] FCM token refreshed: $newToken');
        _fcmToken = newToken;
        await syncTokens();
      });
    } catch (e) {
      debugPrint('[Push] onTokenRefresh setup error: $e');
    }

    // --- Foreground message handler ---
    // Mirrors App.tsx messaging().onMessage
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('[Push] onMessage setup error: $e');
    }

    // --- Notification-tap deep linking ---
    await _setupNotificationTapHandlers();
  }

  // ---------------------------------------------------------------------------
  // Notification-tap deep linking → open the exact chat (not the chat list).
  // Handles: app terminated (getInitialMessage), app backgrounded
  // (onMessageOpenedApp), and a pending local-notification tap payload.
  // ---------------------------------------------------------------------------

  Future<void> _setupNotificationTapHandlers() async {
    // App backgrounded → user tapped an FCM notification.
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        _navigateFromData(m.data);
      });
    } catch (e) {
      debugPrint('[Push] onMessageOpenedApp setup error: $e');
    }

    // App was terminated and launched by tapping an FCM notification.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _deferNavigate(() => _navigateFromData(initial.data));
      }
    } catch (e) {
      debugPrint('[Push] getInitialMessage error: $e');
    }

    // A tapped local notification persisted a route (foreground/terminated).
    try {
      final pending = await LocalNotificationsService.consumePendingPayload();
      if (pending != null && pending.isNotEmpty) {
        _deferNavigate(() => _go(pending));
      }
    } catch (e) {
      debugPrint('[Push] pending payload error: $e');
    }
  }

  /// Navigate to the chat referenced by an FCM data payload.
  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'message') {
      final senderId = (data['senderId'] ??
              data['actor_id'] ??
              data['actorId'] ??
              '')
          .toString();
      if (senderId.isNotEmpty) _go('/chats/$senderId');
    }
    // Calls are handled by CallKit / the call overlay, not chat navigation.
  }

  void _go(String route) {
    try {
      _ref.read(goRouterProvider).go(route);
    } catch (e) {
      debugPrint('[Push] navigation error: $e');
    }
  }

  /// Defer navigation to the next frame so the router/first screen is ready
  /// (important on cold start from a terminated tap).
  void _deferNavigate(void Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), action);
    });
  }

  Future<void> _acquireFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      if (Platform.isIOS) {
        // iOS requires APNs registration first
        try {
          await messaging.setAutoInitEnabled(true);
          await messaging.getAPNSToken();
        } catch (e) {
          debugPrint('[Push] APNs setup error: $e');
        }
      }

      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        debugPrint('[Push] getToken() attempt 1 failed: $e');
      }

      // Retry once after 3s on iOS (mirrors usePushNotifications.ts retry)
      if (token == null && Platform.isIOS) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          token = await messaging.getToken();
        } catch (e) {
          debugPrint('[Push] getToken() attempt 2 failed: $e');
        }
      }

      if (token != null) {
        _fcmToken = token;
        debugPrint('[Push] FCM token obtained');
        await syncTokens();
      } else {
        debugPrint('[Push] FCM token not available');
      }
    } catch (e) {
      debugPrint('[Push] _acquireFcmToken error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // syncTokens — PATCH /users/me { fcm_token, voip_token, platform }
  // Mirrors App.tsx unified token sync effect + helper.ts registerPushToken
  // ---------------------------------------------------------------------------

  Future<void> syncTokens() async {
    try {
      final auth = _ref.read(authProvider);
      if (!auth.isLoggedIn) {
        debugPrint('[Push] syncTokens skipped — not logged in');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      final patch = <String, dynamic>{
        'platform': platform,
      };

      if (_fcmToken != null) {
        patch['fcm_token'] = _fcmToken;
      }

      // VoIP token (iOS only) — obtained from VoipPushService
      if (Platform.isIOS) {
        final voipService = _ref.read(voipPushServiceProvider);
        if (voipService.voipToken != null) {
          patch['voip_token'] = voipService.voipToken;
        }
      }

      if (patch.length <= 1) {
        // Only platform — no tokens yet; skip to avoid a no-op PATCH
        debugPrint('[Push] syncTokens: no tokens to sync yet');
        return;
      }

      debugPrint('[Push] Syncing tokens to server (platform=$platform)');
      await _ref.read(meProvider.notifier).patchMe(patch);
      debugPrint('[Push] Token sync complete');
    } catch (e) {
      debugPrint('[Push] syncTokens error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // Mirrors App.tsx messaging().onMessage
  // ---------------------------------------------------------------------------

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
        '[Push] Foreground message: ${message.messageId} data=${message.data}');

    try {
      final type = message.data['type']?.toString();

      if (type == 'call') {
        // Incoming call push in foreground — show CallKit
        // Backend push uses sessionId/senderName/callAction; accept camelCase too.
        final subType =
            (message.data['subType'] ?? message.data['callAction'])?.toString();
        final callId =
            (message.data['callId'] ?? message.data['sessionId'] ?? '')
                .toString();
        final callerName = (message.data['callerName'] ??
                message.data['senderName'] ??
                'Unknown')
            .toString();
        final callerAvatar =
            (message.data['callerAvatar'] ?? message.data['avatar'])
                ?.toString();
        final callType = message.data['callType']?.toString() ?? 'audio';
        final isVideo = callType == 'video';

        if (subType == 'initiated' || subType == null) {
          final callkitService = _ref.read(callkitServiceProvider);
          await callkitService.displayIncomingCall(
            callId: callId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            isVideo: isVideo,
          );
        } else if (subType == 'ended' || subType == 'cancelled') {
          final callkitService = _ref.read(callkitServiceProvider);
          await callkitService.endCall(callId);
          _ref.read(callOverlayProvider.notifier).clearCall();
        }
      } else {
        // Chat or other notification — show local notification
        final senderName = message.data['senderName']?.toString() ??
            message.notification?.title ??
            'New message';
        final body = message.data['body']?.toString() ??
            message.notification?.body ??
            '';
        final roomId =
            (message.data['roomId'] ?? message.data['room_id'] ?? '').toString();

        await LocalNotificationsService.showChatNotification(
          title: senderName,
          body: body,
          payload: 'chat:$roomId',
        );

        // Refresh notifications provider to update badge count
        try {
          _ref.invalidate(notificationsProvider);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Push] _handleForegroundMessage error: $e');
    }
  }

  void dispose() {}
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
