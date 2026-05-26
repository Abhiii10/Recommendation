enum DetectedLanguage {
  english,
  nepali,
  romanizedNepali,
  mixed,
  unknown,
}

class LanguageDetectionResult {
  final DetectedLanguage primaryLanguage;
  final Map<DetectedLanguage, double> confidences;
  final double devanagariRatio;
  final double latinRatio;
  final int romanizedDictionaryHits;

  const LanguageDetectionResult({
    required this.primaryLanguage,
    required this.confidences,
    required this.devanagariRatio,
    required this.latinRatio,
    required this.romanizedDictionaryHits,
  });

  double confidenceFor(DetectedLanguage language) =>
      confidences[language] ?? 0.0;

  double get confidence => confidenceFor(primaryLanguage);

  bool get isNepali =>
      primaryLanguage == DetectedLanguage.nepali ||
      primaryLanguage == DetectedLanguage.romanizedNepali ||
      primaryLanguage == DetectedLanguage.mixed;

  bool get isEnglish => primaryLanguage == DetectedLanguage.english;

  String get languageCode {
    switch (primaryLanguage) {
      case DetectedLanguage.nepali:
      case DetectedLanguage.romanizedNepali:
      case DetectedLanguage.mixed:
        return 'ne';
      case DetectedLanguage.english:
        return 'en';
      case DetectedLanguage.unknown:
        return 'und';
    }
  }

  Map<String, dynamic> toJson() => {
        'primary_language': primaryLanguage.name,
        'confidence': confidence,
        'confidences':
            confidences.map((key, value) => MapEntry(key.name, value)),
        'devanagari_ratio': devanagariRatio,
        'latin_ratio': latinRatio,
        'romanized_dictionary_hits': romanizedDictionaryHits,
      };
}
