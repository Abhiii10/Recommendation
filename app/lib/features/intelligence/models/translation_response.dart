enum TranslationMethod {
  exactPhrasebook,
  fuzzyPhrasebook,
  template,
  glossary,
  neural,
  online,
  noResult,
}

class TranslationResponse {
  final String translatedText;
  final TranslationMethod method;
  final double confidence;
  final bool isOffline;
  final List<String> alternatives;
  final String? romanized;
  final String? errorMessage;
  final String? matchedId;
  final String sourceLanguage;
  final String targetLanguage;
  final String? sourceLabel;

  const TranslationResponse({
    required this.translatedText,
    required this.method,
    required this.confidence,
    required this.isOffline,
    this.alternatives = const [],
    this.romanized,
    this.errorMessage,
    this.matchedId,
    this.sourceLanguage = 'auto',
    this.targetLanguage = 'auto',
    this.sourceLabel,
  });

  bool get isSuccess =>
      translatedText.trim().isNotEmpty && method != TranslationMethod.noResult;

  String get methodLabel {
    if (sourceLabel != null && sourceLabel!.isNotEmpty) return sourceLabel!;
    switch (method) {
      case TranslationMethod.exactPhrasebook:
        return 'Exact phrase match';
      case TranslationMethod.fuzzyPhrasebook:
        return 'Fuzzy phrase match';
      case TranslationMethod.template:
        return 'Template translation';
      case TranslationMethod.glossary:
        return 'Glossary translation';
      case TranslationMethod.neural:
        return 'Offline neural model';
      case TranslationMethod.online:
        return 'Online fallback';
      case TranslationMethod.noResult:
        return 'No match';
    }
  }
}
