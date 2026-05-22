import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppTelemetry {
  AppTelemetry._();

  static final AppTelemetry instance = AppTelemetry._();

  bool _posthogReady = false;
  bool _sentryReady = false;

  bool get posthogReady => _posthogReady;
  bool get sentryReady => _sentryReady;

  Future<void> initialize() async {
    await Future.wait([
      _initializeSentry(),
      _initializePostHog(),
    ]);
  }

  Future<void> captureEvent(
    String name, {
    Map<String, Object?> properties = const {},
  }) async {
    if (!_posthogReady) return;

    try {
      await Posthog().capture(
        eventName: name,
        properties: _safeProperties(properties),
      );
    } catch (_) {}
  }

  Future<void> captureException(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) async {
    if (_sentryReady) {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          for (final entry in context.entries) {
            scope.setContexts(entry.key, entry.value);
          }
        },
      );
    }

    if (_posthogReady) {
      await Posthog().captureException(
        error: error,
        stackTrace: stackTrace,
        properties: _safeProperties(context),
      );
    }
  }

  Future<void> _initializeSentry() async {
    const configuredDsn = String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue: '',
    );
    final dsn = configuredDsn.trim();

    if (dsn.isEmpty) return;

    try {
      await SentryFlutter.init((options) {
        options.dsn = dsn;
        options.tracesSampleRate = kReleaseMode ? 0.10 : 0.0;
        options.enableAutoSessionTracking = true;
        options.attachScreenshot = false;
      });

      _sentryReady = true;
    } catch (_) {
      _sentryReady = false;
    }
  }

  Future<void> _initializePostHog() async {
    const configuredToken = String.fromEnvironment(
      'POSTHOG_API_KEY',
      defaultValue: '',
    );
    final token = configuredToken.trim();

    if (token.isEmpty) return;

    try {
      final config = PostHogConfig(token);
      const configuredHost = String.fromEnvironment(
        'POSTHOG_HOST',
        defaultValue: '',
      );
      final host = configuredHost.trim();

      if (host.isNotEmpty) {
        config.host = host;
      }

      config.debug = kDebugMode;
      config.captureApplicationLifecycleEvents = true;
      config.sessionReplay = false;
      config.personProfiles = PostHogPersonProfiles.identifiedOnly;

      await Posthog().setup(config);
      _posthogReady = true;
    } catch (_) {
      _posthogReady = false;
    }
  }

  Map<String, Object> _safeProperties(Map<String, Object?> properties) {
    return {
      for (final entry in properties.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }
}
