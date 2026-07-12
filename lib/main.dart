import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/device_id.dart';
import 'core/version_service.dart';
import 'services/local_notifications_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stable per-install id (used for multi-device push routing + socket handshake).
  try {
    await DeviceId.ensure();
  } catch (e) {
    debugPrint('[main] DeviceId.ensure error: $e');
  }

  // DEBUG-ONLY diagnostic: print the exact exception behind any ErrorWidget to
  // the device log and show it as readable text. Release uses default handling.
  if (kDebugMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('███ ERRORWIDGET ███ ${details.exceptionAsString()}');
      debugPrint('███ STACK ███ ${details.stack}');
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          details.exceptionAsString(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.yellowAccent, fontSize: 11),
        ),
      );
    };
  }

  // ---------------------------------------------------------------------------
  // Load environment variables first — everything else may depend on them.
  // ---------------------------------------------------------------------------
  await dotenv.load(fileName: '.env');

  // ---------------------------------------------------------------------------
  // Initialise Firebase (reads GoogleService-Info.plist / google-services.json).
  // Required for FCM push notifications — token retrieval and message delivery
  // both need this. Guarded so a config error never blocks app startup.
  // ---------------------------------------------------------------------------
  try {
    await Firebase.initializeApp();
    debugPrint('[main] Firebase initialised');
  } catch (e) {
    debugPrint('[main] Firebase.initializeApp error: $e');
  }

  // ---------------------------------------------------------------------------
  // Phase 8: VersionService — compare stored vs. current version.
  // On upgrade, clears the auth token so the user must log in again.
  // Mirrors RN src/lib/VersionService.ts behaviour.
  // ---------------------------------------------------------------------------
  await VersionService.checkAndHandle();

  // ---------------------------------------------------------------------------
  // Phase 6: Initialise local notifications channel before runApp so that
  // the background handler can show chat notifications from a separate isolate.
  // ---------------------------------------------------------------------------
  try {
    await LocalNotificationsService.init();
  } catch (e) {
    debugPrint('[main] LocalNotificationsService.init error: $e');
  }

  // ---------------------------------------------------------------------------
  // Phase 6: Register FCM background message handler.
  //
  // This is a STATIC registration — it does NOT require Firebase.initializeApp().
  // The handler itself (firebaseMessagingBackgroundHandler) is guarded with
  // try/catch, so a missing google-services.json never crashes the app.
  //
  // TODO (Phase 8): After adding google-services.json to android/app/ and
  // GoogleService-Info.plist to ios/Runner/, and applying the google-services
  // Gradle plugin in android/app/build.gradle.kts, real FCM messages will
  // start flowing through this handler.
  // ---------------------------------------------------------------------------
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[main] FCM background handler registered');
  } catch (e) {
    // Thrown when Firebase is not configured — safe to ignore.
    debugPrint(
      '[main] FCM background handler registration skipped '
      '(Firebase not configured): $e',
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 8: Sentry — wrap runApp so all unhandled Dart + Flutter errors are
  // captured.  If Sentry init itself fails (e.g. network unavailable at boot)
  // we fall back to a plain runApp so startup is never blocked.
  // ---------------------------------------------------------------------------
  // Start the app IMMEDIATELY. Previously runApp was nested inside
  // SentryFlutter.init(appRunner:), and when the app is launched cold in the
  // background by a call push, that init can hang — so runApp never ran, the UI
  // never built, and an accepted call could never connect. Launch first, then
  // initialise Sentry in the background (non-blocking).
  debugPrint('[main] starting runApp');
  runApp(
    const ProviderScope(
      child: RichBengaliApp(),
    ),
  );

  unawaited(() async {
    try {
      await SentryFlutter.init((options) {
        options.dsn =
            'https://1e9d3efdd86543c613e71b0572d4c963@o4510619795259392.ingest.us.sentry.io/4510680694325248';
        options.tracesSampleRate = 0.2;
        options.profilesSampleRate = 0.1;
        options.attachStacktrace = true;
      });
    } catch (e) {
      debugPrint('[main] Sentry init error (non-fatal): $e');
    }
  }());
}
