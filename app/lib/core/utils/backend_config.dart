import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  const BackendConfig._();

  static String get anthropicApiKey {
    final key = dotenv.maybeGet('ANTHROPIC_API_KEY')?.trim() ?? '';
    assert(
      key.isNotEmpty,
      '\n\nWARNING: ANTHROPIC_API_KEY not set.\n'
      'Add ANTHROPIC_API_KEY=your_key to your app/.env file\n',
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
  String fromEnv = '';

  try {
    fromEnv = dotenv.maybeGet('AI_BACKEND_BASE_URL')?.trim() ?? '';
  } catch (_) {
    fromEnv = '';
  }
  if (fromEnv.isNotEmpty) {
    debugPrint('🟢 backendBaseUrl from .env → $fromEnv');
    return fromEnv;
  }

  // Hardcoded fallback — update this to your LAN IP
  const fallback = 'http://192.168.1.200:8000';
  debugPrint('🟡 backendBaseUrl fallback → $fallback');

  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return fallback;
  return 'http://127.0.0.1:8000';
}
