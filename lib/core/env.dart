import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get apiBase =>
      dotenv.env['EXPO_PUBLIC_API_BASE'] ?? 'http://localhost:8080';

  static String get agoraAppId =>
      dotenv.env['EXPO_PUBLIC_AGORA_APP_ID'] ?? '';
}
