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

  const AuthState({this.user, this.token});

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({User? user, String? token, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: token ?? this.token,
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
        state = AuthState(user: user, token: token);
      }
    } catch (_) {
      // If hydration fails, stay logged out
    }
  }

  Future<void> setAuth(String token, User user) async {
    await AppStorage.saveAuth(token, user.toJsonString());
    state = AuthState(user: user, token: token);
  }

  Future<void> logout() async {
    await AppStorage.clearAuth();
    state = const AuthState();
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
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
