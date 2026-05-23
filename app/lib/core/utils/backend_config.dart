import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  const BackendConfig._();

  static String get anthropicApiKey {
    final key = dotenv.maybeGet('ANTHROPIC_API_KEY')?.trim() ?? '';
    assert(
      key.isNotEmpty,
      '\n\nWARNING: ANTHROPIC_API_KEY is not set.\n'
      'Add ANTHROPIC_API_KEY=your_key to your .env file\n',
    );
    return key;
  }

  static void debugAssertAnthropicApiKeyConfigured() {
    assert(() {
      anthropicApiKey;
      return true;
    }());
  }
}

String get backendBaseUrl {
  const defined = String.fromEnvironment('AI_BACKEND_BASE_URL');
  final compileTimeConfigured = defined.trim();

  if (compileTimeConfigured.isNotEmpty) {
    return compileTimeConfigured;
  }

  final configured = dotenv.maybeGet('AI_BACKEND_BASE_URL')?.trim() ?? '';

  if (configured.isNotEmpty) {
    return configured;
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://192.168.18.132:8000'; // fallback if .env missing
  }

  return 'http://127.0.0.1:8000';
}
