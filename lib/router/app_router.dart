import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/tabs/home_screen.dart';
import '../screens/tabs/favorites_screen.dart';
import '../screens/tabs/chats_screen.dart';
import '../screens/tabs/plans_screen.dart';
import '../screens/tabs/me_screen.dart';
import '../screens/tabs/user_detail_screen.dart';
import '../screens/tabs/chat_detail_screen.dart';
import '../screens/tabs/earnings_screen.dart';
import '../screens/tabs/payout_screen.dart';
import '../screens/tabs/subscription_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    debugLogDiagnostics: false,

    // Deep link scheme: richbengali://payout?status=...
    // go_router handles custom schemes via redirect or a uri parser.
    // We map this by handling payout route directly.

    redirect: (context, state) {
      final uri = state.uri;

      // --- Custom-scheme deep-link returns from Stripe / Wise ---
      // e.g. richbengali://payout?status=success  (host = 'payout')
      //      richbengali://subscription?status=success
      // go_router can't match these directly, so remap to the real routes.
      if (uri.host == 'payout' || uri.path == '/payout') {
        final status = uri.queryParameters['status'] ??
            uri.queryParameters['payoutStatus'] ??
            '';
        return '/me/payout?status=$status';
      }
      if (uri.host == 'subscription' || uri.path == '/subscription') {
        final status = uri.queryParameters['status'] ?? '';
        return '/me/subscription?status=$status';
      }

      final path = uri.path;

      // --- Wait for the stored session to load before routing, so a cold start
      //     (e.g. launched by tapping a notification) never flashes /login. ---
      if (!notifier.hydrated) {
        return path == '/splash' ? null : '/splash';
      }
      // Hydrated: leave the splash for the right destination.
      if (path == '/splash') {
        return notifier.isLoggedIn ? '/home' : '/login';
      }

      // --- Auth gating ---
      final isLoggedIn = notifier.isLoggedIn;

      final isAuthRoute = path == '/login' || path == '/register' || path == '/forgot';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }
      return null;
    },

    routes: [
      // Splash — shown while the stored session is loading on startup.
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot',
        builder: (context, state) => const ForgotScreen(),
      ),

      // Main shell with 5 branches (each keeps its own navigator stack)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'user/:id',
                    builder: (context, state) => UserDetailScreen(
                      userId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Favorites
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
                routes: [
                  GoRoute(
                    path: 'user/:id',
                    builder: (context, state) => UserDetailScreen(
                      userId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Chats
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (context, state) => const ChatsScreen(),
                routes: [
                  GoRoute(
                    path: 'user/:id',
                    builder: (context, state) => UserDetailScreen(
                      userId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ChatDetailScreen(
                      chatId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 3: Plans (male-only — branch always exists, tab is hidden for females in shell)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plans',
                builder: (context, state) => const PlansScreen(),
              ),
            ],
          ),

          // Branch 4: Me
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const MeScreen(),
                routes: [
                  GoRoute(
                    path: 'earnings',
                    builder: (context, state) => const EarningsScreen(),
                  ),
                  GoRoute(
                    path: 'payout',
                    builder: (context, state) => PayoutScreen(
                      status: state.uri.queryParameters['status'],
                      payoutStatus:
                          state.uri.queryParameters['payoutStatus'],
                    ),
                  ),
                  GoRoute(
                    path: 'subscription',
                    builder: (context, state) => SubscriptionScreen(
                      status: state.uri.queryParameters['status'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Splash — a neutral loading screen shown until auth hydration completes, so a
// cold start never flashes the login screen.
// ---------------------------------------------------------------------------

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
