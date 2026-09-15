import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import 'env.dart';
import 'storage.dart';

/// Renews an expired session in the background.
///
/// A 401 used to wipe the stored token and nothing else — the auth state was
/// left untouched, so the app went on believing it was signed in while every
/// request after that went out with no token. That is what a user saw as being
/// logged in with a dead app: no balance, no incoming calls, no way back short
/// of reinstalling.
///
/// Now a 401 tries to roll the session forward and replays the request. Only a
/// refusal from the server — the account is gone, or the token was never ours —
/// ends the session, and when it does the app is actually told, so it lands on
/// the login screen instead of sitting there broken.
class _SessionRefresher {
  _SessionRefresher(this._ref);

  final Ref _ref;

  /// Single-flight: a burst of parallel 401s must trigger one refresh, not one
  /// per request.
  Future<String?>? _inFlight;

  Future<String?> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    final token = await AppStorage.getToken();
    if (token == null || token.isEmpty) return null;

    // A bare Dio: the interceptor below must not see this request, or a failing
    // refresh would recurse into itself.
    final bare = Dio(BaseOptions(
      baseUrl: Env.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (_) => true,
    ));

    try {
      final resp = await bare.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = resp.data;
      if (resp.statusCode == 200 && data is Map && data['token'] is String) {
        final fresh = data['token'] as String;
        // Through the notifier, so the socket — which reconnects on a token
        // change — picks the new one up too.
        await _ref.read(authProvider.notifier).applyRefreshedToken(fresh);
        return fresh;
      }

      // 401 here is the server saying this session is genuinely finished.
      if (resp.statusCode == 401) {
        await _ref.read(authProvider.notifier).logout();
        return null;
      }
    } catch (_) {
      // Offline or the server is down. Keep the session — this is exactly the
      // case where throwing the user out would be wrong.
    }
    return null;
  }
}

Dio _buildDio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  final refresher = _SessionRefresher(ref);

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await AppStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (DioException err, handler) async {
      final path = err.requestOptions.path;
      final isAuthCall = path.contains('/auth/');

      if (err.response?.statusCode != 401 || isAuthCall) {
        return handler.next(err);
      }

      // Replay guard: if the retry itself 401s, give up rather than loop.
      if (err.requestOptions.extra['__retried'] == true) {
        return handler.next(err);
      }

      final fresh = await refresher.refresh();
      if (fresh == null) return handler.next(err);

      final req = err.requestOptions;

      // A multipart body is a one-shot stream — it has already been consumed,
      // so it cannot be replayed. The session is renewed either way, so the
      // next send succeeds; surface this one as a normal failure.
      if (req.data is FormData) return handler.next(err);

      req.extra = {...req.extra, '__retried': true};
      req.headers['Authorization'] = 'Bearer $fresh';
      try {
        final replay = await dio.fetch(req);
        return handler.resolve(replay);
      } catch (e) {
        return handler.next(e is DioException ? e : err);
      }
    },
  ));

  return dio;
}

final dioProvider = Provider<Dio>((ref) => _buildDio(ref));
