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
    initialLocation: '/login',
    refreshListenable: notifier,
    debugLogDiagnostics: false,

    // Deep link scheme: richbengali://payout?status=...
    // go_router handles custom schemes via redirect or a uri parser.
    // We map this by handling payout route directly.

    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final path = state.uri.path;

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
