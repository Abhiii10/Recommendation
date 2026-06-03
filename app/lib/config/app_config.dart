enum BackendEnvironment {
  emulator,
  physicalDevice,
  production,
}

class AppConfig {
  const AppConfig._();

  static const String emulatorBackendUrl = 'http://10.0.2.2:8000';
  static const String physicalDeviceBackendUrl = 'http://192.168.101.2:8000';
  static const String productionBackendUrl =
      'https://your-production-backend.example.com';

  static const String _customBackendUrl = String.fromEnvironment(
    'AI_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const String _backendEnvironment = String.fromEnvironment(
    'APP_BACKEND_ENV',
    defaultValue: 'physical',
  );

  static const int backendHealthAttempts = 3;
  static const Duration backendHealthTimeout = Duration(seconds: 10);
  static const Duration backendHealthInitialRetryDelay =
      Duration(milliseconds: 500);

  static BackendEnvironment get backendEnvironment {
    switch (_backendEnvironment.trim().toLowerCase()) {
      case 'emulator':
      case 'android-emulator':
      case 'android_emulator':
        return BackendEnvironment.emulator;
      case 'production':
      case 'prod':
        return BackendEnvironment.production;
      case 'physical':
      case 'physical-device':
      case 'physical_device':
      default:
        return BackendEnvironment.physicalDevice;
    }
  }

  static String get baseUrl {
    final override = _customBackendUrl.trim();
    if (override.isNotEmpty) return _removeTrailingSlash(override);

    return switch (backendEnvironment) {
      BackendEnvironment.emulator => emulatorBackendUrl,
      BackendEnvironment.physicalDevice => physicalDeviceBackendUrl,
      BackendEnvironment.production => productionBackendUrl,
    };
  }

  static String get backendUnavailableMessage =>
      'Backend is unreachable. Check your connection and make sure the '
      'FastAPI Docker server is running at $baseUrl.';

  static String _removeTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
