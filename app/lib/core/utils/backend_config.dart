import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class BackendHealthResult {
  final bool reachable;
  final Uri healthUri;
  final int attempts;
  final int? statusCode;
  final String? status;
  final Object? error;

  const BackendHealthResult({
    required this.reachable,
    required this.healthUri,
    required this.attempts,
    this.statusCode,
    this.status,
    this.error,
  });

  String get userMessage {
    if (reachable) {
      return 'Backend is online.';
    }

    return 'Backend is offline. Start the FastAPI server and make sure '
        '$healthUri is reachable from this device.';
  }
}

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

  static Uri uri(String path, {String? baseUrl}) {
    final resolvedBaseUrl = baseUrl ?? backendBaseUrl;
    final base = resolvedBaseUrl.endsWith('/')
        ? resolvedBaseUrl.substring(0, resolvedBaseUrl.length - 1)
        : resolvedBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  static bool isHealthyStatus(Object? status) {
    final normalized = status?.toString().trim().toLowerCase();
    return normalized == 'ok' || normalized == 'healthy';
  }

  static Future<BackendHealthResult> checkBackendHealth({
    String? baseUrl,
    int attempts = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final healthUri = uri('/health', baseUrl: baseUrl);
    Object? lastError;
    int? lastStatusCode;
    String? lastStatus;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        debugPrint('Backend health attempt $attempt/$attempts -> $healthUri');
        final response = await http.get(healthUri).timeout(timeout);
        lastStatusCode = response.statusCode;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            lastStatus = decoded['status']?.toString();
            if (isHealthyStatus(lastStatus)) {
              return BackendHealthResult(
                reachable: true,
                healthUri: healthUri,
                attempts: attempt,
                statusCode: response.statusCode,
                status: lastStatus,
              );
            }
          }
        }
      } catch (error) {
        lastError = error;
        debugPrint('Backend health attempt $attempt failed -> $error');
      }

      if (attempt < attempts) {
        await Future<void>.delayed(retryDelay);
      }
    }

    return BackendHealthResult(
      reachable: false,
      healthUri: healthUri,
      attempts: attempts,
      statusCode: lastStatusCode,
      status: lastStatus,
      error: lastError,
    );
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
    debugPrint('backendBaseUrl from .env -> $fromEnv');
    return fromEnv;
  }

  // Hardcoded fallback; update this to your LAN IP when app/.env is missing.
  const fallback = 'http://192.168.1.200:8000';
  debugPrint('backendBaseUrl fallback -> $fallback');

  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return fallback;
  return 'http://127.0.0.1:8000';
}
