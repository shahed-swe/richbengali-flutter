import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'screens/call/ongoing_call_screen.dart';
import 'services/callkit_service.dart';
import 'services/local_notifications_service.dart';
import 'services/push_service.dart';
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
    WidgetsBinding.instance.addObserver(this);

    // Set up CallKit event listeners immediately (before auth).
    // Mirrors VoipNotificationHandler.initialize() called on App.tsx mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(callkitServiceProvider).setupListeners();
      } catch (e) {
        debugPrint('[App] callkitService.setupListeners error: $e');
      }
    });
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

    // Init FCM — requests permission, gets token, sets up foreground handler
    try {
      await ref.read(pushServiceProvider).init();
    } catch (e) {
      debugPrint('[App] pushService.init error: $e');
    }

    // iOS: register for VoIP push (PushKit) — no-op on Android.
    // Mirrors App.tsx VoipPushNotification.addEventListener('register', ...)
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

    // Trigger on first build if token was already restored from storage
    final auth = ref.read(authProvider);
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
