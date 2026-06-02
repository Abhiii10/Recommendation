import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String backendBaseUrl = String.fromEnvironment(
  'AI_BACKEND_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

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

  static final ValueNotifier<BackendHealthResult?> health =
      ValueNotifier<BackendHealthResult?>(null);

  static Timer? _healthMonitorTimer;
  static bool _healthCheckInFlight = false;

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
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final healthUri = uri('/health', baseUrl: baseUrl);
    Object? lastError;
    int? lastStatusCode;
    String? lastStatus;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        if (kDebugMode) {
          debugPrint(
            'Backend health attempt $attempt/$attempts -> $healthUri',
          );
        }
        final response = await http.get(healthUri).timeout(timeout);
        lastStatusCode = response.statusCode;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            lastStatus = decoded['status']?.toString();
            if (isHealthyStatus(lastStatus)) {
              final result = BackendHealthResult(
                reachable: true,
                healthUri: healthUri,
                attempts: attempt,
                statusCode: response.statusCode,
                status: lastStatus,
              );
              health.value = result;
              return result;
            }
          }
        }
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('Backend health attempt $attempt failed -> $error');
        }
      }

      if (attempt < attempts) {
        await Future<void>.delayed(retryDelay);
      }
    }

    final result = BackendHealthResult(
      reachable: false,
      healthUri: healthUri,
      attempts: attempts,
      statusCode: lastStatusCode,
      status: lastStatus,
      error: lastError,
    );
    health.value = result;
    return result;
  }

  static Future<void> startHealthMonitor({
    Duration interval = const Duration(seconds: 30),
  }) async {
    debugPrint('Backend configured URL -> $backendBaseUrl');
    await refreshBackendHealth(logResult: true);
    _healthMonitorTimer?.cancel();
    _healthMonitorTimer = Timer.periodic(
      interval,
      (_) => unawaited(refreshBackendHealth(logResult: true)),
    );
  }

  static Future<BackendHealthResult> refreshBackendHealth({
    bool logResult = false,
  }) async {
    if (_healthCheckInFlight) {
      return health.value ??
          BackendHealthResult(
            reachable: false,
            healthUri: uri('/health'),
            attempts: 0,
            error: 'Backend health check already running',
          );
    }

    _healthCheckInFlight = true;
    try {
      final result = await checkBackendHealth(
        attempts: 1,
        timeout: const Duration(seconds: 5),
      );
      health.value = result;
      if (logResult) {
        final mode = result.reachable ? 'online mode' : 'offline mode';
        debugPrint(
          'Backend health -> $mode (${result.healthUri}, '
          'status: ${result.statusCode ?? 'n/a'}, '
          'error: ${result.error ?? 'none'})',
        );
      }
      return result;
    } finally {
      _healthCheckInFlight = false;
    }
  }

  static bool get isBackendReachable => health.value?.reachable == true;

  static void stopHealthMonitor() {
    _healthMonitorTimer?.cancel();
    _healthMonitorTimer = null;
  }
}
