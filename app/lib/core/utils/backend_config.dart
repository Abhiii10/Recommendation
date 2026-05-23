import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig._();

  static String get anthropicApiKey {
    const key = String.fromEnvironment(
      'ANTHROPIC_API_KEY',
      defaultValue: '',
    );
    assert(
      key.isNotEmpty,
      '\n\nWARNING: ANTHROPIC_API_KEY not set.\n'
      'Run: flutter run --dart-define=ANTHROPIC_API_KEY=your_key\n',
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
  const defined = String.fromEnvironment(
    'AI_BACKEND_BASE_URL',
    defaultValue: '',
  );
  if (defined.trim().isNotEmpty) return defined.trim();

  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}
