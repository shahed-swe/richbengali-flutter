import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage.dart';
import '../models/user.dart';

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

class AuthState {
  final User? user;
  final String? token;

  /// False until the token has been read from storage on startup. The router
  /// shows a splash while this is false, so we never flash the login screen on
  /// a cold start (e.g. when launched from a notification while logged in).
  final bool hydrated;

  const AuthState({this.user, this.token, this.hydrated = false});

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith(
      {User? user, String? token, bool clearUser = false, bool? hydrated}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: token ?? this.token,
      hydrated: hydrated ?? this.hydrated,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Hydrate synchronously is not possible; kick off async hydration.
    _hydrate();
    return const AuthState();
  }

  Future<void> _hydrate() async {
    try {
      final token = await AppStorage.getToken();
      final userJson = await AppStorage.getUser();
      if (token != null && userJson != null) {
        final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        state = AuthState(user: user, token: token, hydrated: true);
        return;
      }
    } catch (_) {
      // If hydration fails, stay logged out
    }
    // No stored session (or failure) — mark hydrated so the router routes to login.
    state = const AuthState(hydrated: true);
  }

  Future<void> setAuth(String token, User user) async {
    await AppStorage.saveAuth(token, user.toJsonString());
    state = AuthState(user: user, token: token, hydrated: true);
  }

  Future<void> logout() async {
    await AppStorage.clearAuth();
    state = const AuthState(hydrated: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ---------------------------------------------------------------------------
// RouterNotifier — bridges Riverpod auth state to go_router's refreshListenable
// ---------------------------------------------------------------------------

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    // Listen to auth state changes and notify go_router
    _ref.listen<AuthState>(authProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;

  bool get isLoggedIn => _ref.read(authProvider).isLoggedIn;
  bool get hydrated => _ref.read(authProvider).hydrated;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
