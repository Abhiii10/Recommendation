import 'package:flutter/foundation.dart';

class IntelligenceLogger {
  final String scope;
  final bool enabled;

  const IntelligenceLogger(this.scope, {this.enabled = !kReleaseMode});

  void info(String message) {
    if (enabled) debugPrint('[$scope] $message');
  }

  void warning(String message, [Object? error]) {
    if (enabled) {
      debugPrint(
          '[$scope][warning] $message${error == null ? '' : ': $error'}');
    }
  }
}
