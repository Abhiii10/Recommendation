enum IntelligenceTranslationDirection {
  auto,
  englishToNepali,
  nepaliToEnglish,
}

class TranslationRequest {
  final String text;
  final IntelligenceTranslationDirection direction;
  final bool allowOnline;
  final bool allowNeural;

  const TranslationRequest({
    required this.text,
    this.direction = IntelligenceTranslationDirection.auto,
    this.allowOnline = true,
    this.allowNeural = true,
  });
}
