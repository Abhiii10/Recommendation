class IntelligenceException implements Exception {
  final String message;
  final Object? cause;

  const IntelligenceException(this.message, [this.cause]);

  @override
  String toString() => cause == null
      ? 'IntelligenceException: $message'
      : 'IntelligenceException: $message ($cause)';
}

class IntelligenceAssetException extends IntelligenceException {
  const IntelligenceAssetException(super.message, [super.cause]);
}

class IntelligenceModelUnavailableException extends IntelligenceException {
  const IntelligenceModelUnavailableException(super.message, [super.cause]);
}
