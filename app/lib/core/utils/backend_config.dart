import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig._();

  static String get anthropicApiKey {
    const key = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
    assert(
      key.isNotEmpty,
      '\n\nWARNING: ANTHROPIC_API_KEY is not set.\n'
      'Run with: flutter run --dart-define=ANTHROPIC_API_KEY=your_key_here\n',
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
  const url = String.fromEnvironment('AI_BACKEND_BASE_URL', defaultValue: '');
  final configured = url.trim();

  if (configured.isNotEmpty) {
    return configured;
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }

  return 'http://127.0.0.1:8000';
}
