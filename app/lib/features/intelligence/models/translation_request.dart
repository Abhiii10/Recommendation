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

  String get sourceLanguage {
    switch (direction) {
      case IntelligenceTranslationDirection.englishToNepali:
        return 'en';
      case IntelligenceTranslationDirection.nepaliToEnglish:
        return 'ne';
      case IntelligenceTranslationDirection.auto:
        return _looksLikeNepali(text) ? 'ne' : 'en';
    }
  }

  String get targetLanguage => sourceLanguage == 'ne' ? 'en' : 'ne';

  static bool _looksLikeNepali(String value) {
    final hasDevanagari = value.codeUnits
        .any((codeUnit) => codeUnit >= 0x0900 && codeUnit <= 0x097F);
    if (hasDevanagari) return true;

    final normalized = value.toLowerCase();
    return const [
      'namaste',
      'malai',
      'kati',
      'khana',
      'pani',
      'basna',
      'jana',
      'kaha',
      'cha',
      'chha',
      'chahiyo',
      'sasto',
      'ramro',
      'bato',
      'gaun',
      'homestay',
    ].any(normalized.contains);
  }
}
