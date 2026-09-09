import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'screens/call/ongoing_call_screen.dart';
import 'services/callkit_service.dart';
import 'services/local_notifications_service.dart';
import 'services/push_service.dart';
import 'services/socket_service.dart';
import 'services/voip_push_service.dart';
import 'state/auth_provider.dart';
import 'state/conversations_provider.dart';
import 'state/favorites_provider.dart';
import 'state/me_provider.dart';
import 'state/notifications_provider.dart';
import 'state/users_provider.dart';
import 'theme/theme.dart';
import 'widgets/call/minimized_call.dart';

// ---------------------------------------------------------------------------
// RichBengaliApp — Phase 6: converted to ConsumerStatefulWidget so we can
// observe lifecycle events and drive push/callkit service startup.
// Mirrors App.tsx MainApp effects.
// ---------------------------------------------------------------------------

class RichBengaliApp extends ConsumerStatefulWidget {
  const RichBengaliApp({super.key});

  @override
  ConsumerState<RichBengaliApp> createState() => _RichBengaliAppState();
}

class _RichBengaliAppState extends ConsumerState<RichBengaliApp>
    with WidgetsBindingObserver {
  bool _servicesStarted = false;
  String? _previousUserId;

  @override
  void initState() {
    super.initState();
    debugPrint('[App] initState (UI reached)');
    WidgetsBinding.instance.addObserver(this);

    // Kick core services NOW, synchronously in initState — NOT in a post-frame
    // callback and NOT relying on build(). On a headless cold-start from a call
    // push, the app is launched without a foreground activity, so no frame
    // renders and build() never runs; anything deferred there (and any lazy
    // provider only read in build) would never start. We must:
    //  • set up CallKit listeners,
    //  • force-create the socket service so it connects once auth hydrates
    //    (its onConnect then recovers the accepted call), and
    //  • start push services if already logged in.
    try {
      ref.read(callkitServiceProvider).setupListeners();
      ref.read(socketServiceProvider); // force-create → connect on auth hydrate

      // Start push services as soon as auth is known — via listenManual so it is
      // NOT tied to build()/frames. AuthState starts logged-out and _hydrate()
      // restores the session asynchronously; a returning user therefore never
      // produced a "logged out -> logged in" transition inside build(), and when
      // the app starts with the screen off Flutter renders no frames at all, so
      // anything relying on build() or addPostFrameCallback never runs. That left
      // a restored session registering NO push token (no notifications, no calls).
      // fireImmediately covers the already-hydrated case.
      ref.listenManual<AuthState>(
        authProvider,
        (prev, next) {
          debugPrint('[App] auth changed: hydrated=${next.hydrated} '
              'isLoggedIn=${next.isLoggedIn} started=$_servicesStarted');
          if (next.isLoggedIn && !_servicesStarted) {
            _startPushServices();
          } else if (!next.isLoggedIn && _servicesStarted) {
            _stopPushServices();
          }
        },
        fireImmediately: true,
      );
    } catch (e) {
      debugPrint('[App] initState service kick error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle — mirrors App.tsx AppState change handler
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tell the backend our foreground/background state so it suppresses the
    // native call push (CallKit/FCM) ONLY while we're truly foreground. Without
    // this, iOS keeps a backgrounded app's socket "connected" for ~85s and the
    // backend wrongly skips the VoIP push → a just-closed iPhone never rings.
    try {
      final socket = ref.read(socketServiceProvider);
      if (state == AppLifecycleState.resumed) {
        socket.notifyForeground();
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached ||
          state == AppLifecycleState.hidden) {
        socket.notifyBackground();
      }
    } catch (e) {
      debugPrint('[App] lifecycle notify error: $e');
    }

    if (state == AppLifecycleState.resumed) {
      // Clear all notifications when app comes to foreground.
      // Mirrors App.tsx AppState 'active' handler (clears badge / Android notifs).
      try {
        LocalNotificationsService.cancelAll();
      } catch (e) {
        debugPrint('[App] cancelAll error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Start push + VoIP services after login.
  // Mirrors the useEffect in App.tsx that fires on [user] change.
  // ---------------------------------------------------------------------------

  Future<void> _startPushServices() async {
    if (_servicesStarted) return;
    _servicesStarted = true;

    debugPrint('[App] Starting push services');

    // iOS: register for VoIP push (PushKit) FIRST. register() also completes any
    // cold-start CallKit accept and delivers the VoIP token. It must NOT be
    // blocked behind pushService.init(), which polls up to ~20s for the APNs
    // token — that delay previously left a just-accepted call hanging on
    // "Calling…" and pushed the first VoIP-token sync ~20s late. No-op on Android.
    if (Platform.isIOS) {
      try {
        final voipService = ref.read(voipPushServiceProvider);
        // When VoIP token arrives from native side, re-sync all tokens to server
        voipService.onTokenReceived = (_) async {
          try {
            await ref.read(pushServiceProvider).syncTokens();
          } catch (e) {
            debugPrint('[App] voip token re-sync error: $e');
          }
        };
        await voipService.register();
      } catch (e) {
        debugPrint('[App] voipPushService.register error: $e');
      }
    }

    // Init FCM FIRST — requests notification permission, gets the FCM token and
    // syncs it to the server. This MUST come before the extra Android prompts:
    // the full-screen-intent request navigates the user out to a system settings
    // page, which would background the app before it ever fetched its token (that
    // left Android registered with no fcm_token at all, so nothing could arrive).
    try {
      await ref.read(pushServiceProvider).init();
    } catch (e) {
      debugPrint('[App] pushService.init error: $e');
    }

    // Android: now ask on-screen for the battery-optimisation exemption (so FCM
    // still arrives when the app is closed) and the Android 14+ full-screen-intent
    // permission (so calls ring full-screen instead of only as a notification).
    // Done AFTER the token is registered, so navigating to settings can't break it.
    if (Platform.isAndroid) {
      try {
        await ref.read(callkitServiceProvider).ensureAndroidCallPermissions();
      } catch (e) {
        debugPrint('[App] android call permissions error: $e');
      }
    }
  }

  void _stopPushServices() {
    _servicesStarted = false;
    // On logout: FCM token refresh listener stays (singleton); CallKit listeners
    // stay active so any lingering native call UI can still be dismissed.
    debugPrint('[App] Push services reset on logout');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // -------------------------------------------------------------------------
    // React to auth state changes — start/stop push services
    // Mirrors App.tsx useEffect on [user]
    // -------------------------------------------------------------------------
    ref.listen<AuthState>(authProvider, (previous, next) {
      final nextUserId = next.user?.id;
      final userChanged = nextUserId != null && nextUserId != _previousUserId;

      if (next.isLoggedIn && !(previous?.isLoggedIn ?? false)) {
        _startPushServices();
      } else if (!next.isLoggedIn && (previous?.isLoggedIn ?? false)) {
        _stopPushServices();
      }

      // Invalidate all user-scoped providers whenever the logged-in user
      // changes (login as a different account) or on logout, so stale data
      // from the previous session is never shown to the next user.
      if (userChanged || (!next.isLoggedIn && (previous?.isLoggedIn ?? false))) {
        try {
          ref.invalidate(meProvider);
          ref.invalidate(usersProvider);
          ref.invalidate(favoritesProvider);
          ref.invalidate(conversationsProvider);
          ref.invalidate(notificationsProvider);
        } catch (e) {
          debugPrint('[App] provider invalidation error: $e');
        }
      }

      _previousUserId = nextUserId;
    });

    // Start push services for an ALREADY logged-in user (session restored from
    // storage). This MUST be a watch, not a read: AuthState starts logged-out and
    // _hydrate() restores the token asynchronously, so a read here only ever sees
    // the pre-hydration state and this never fires. With ref.read the only path
    // left was the "logged out -> logged in" listener above, which a restored
    // session never triggers — so a returning user registered NO push token at
    // all (no notifications, no calls) until they manually logged out and in.
    final auth = ref.watch(authProvider);
    if (auth.isLoggedIn && !_servicesStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPushServices());
    }

    return MaterialApp.router(
      title: 'RichBengali',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      // Global overlay: OngoingCallScreen + MinimizedCall float above all routes
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // The call overlay is rendered ABOVE the router's Navigator, so it
            // has no Overlay ancestor. Material widgets inside it (the beauty
            // Sliders, tooltips, etc.) call Overlay.of and would throw
            // "No Overlay widget found." Give them a dedicated Overlay here.
            Positioned.fill(
              child: Overlay(
                initialEntries: [
                  // Full-screen call UI (renders nothing when no active call).
                  OverlayEntry(
                    builder: (_) => const OngoingCallScreen(),
                  ),
                  // Minimized call bar — full-width at the bottom when minimized.
                  OverlayEntry(
                    builder: (_) => const Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [MinimizedCallBar()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
