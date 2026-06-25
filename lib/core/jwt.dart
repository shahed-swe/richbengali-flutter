import 'package:jwt_decoder/jwt_decoder.dart';

class AppJwt {
  AppJwt._();

  static String? getUserIdFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final payload = JwtDecoder.decode(token);
      final id = payload['id'];
      return id?.toString();
    } catch (_) {
      return null;
    }
  }
}
