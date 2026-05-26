import '../models/language_detection_result.dart';
import '../utils/text_utils.dart';

class LanguageDetector {
  final Set<String> romanizedDictionary;

  const LanguageDetector({this.romanizedDictionary = const {}});

  LanguageDetectionResult detect(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const LanguageDetectionResult(
        primaryLanguage: DetectedLanguage.unknown,
        confidences: {DetectedLanguage.unknown: 1},
        devanagariRatio: 0,
        latinRatio: 0,
        romanizedDictionaryHits: 0,
      );
    }

    var devanagari = 0;
    var latin = 0;
    var letters = 0;
    for (final codeUnit in trimmed.codeUnits) {
      if (TextUtils.isDevanagariCodeUnit(codeUnit)) {
        devanagari++;
        letters++;
      } else if (TextUtils.isLatinCodeUnit(codeUnit)) {
        latin++;
        letters++;
      }
    }

    final devanagariRatio = letters == 0 ? 0.0 : devanagari / letters;
    final latinRatio = letters == 0 ? 0.0 : latin / letters;
    final tokens = TextUtils.normalizeLatin(trimmed).split(' ');
    final romanizedHits = tokens
        .where(
            (token) => token.isNotEmpty && romanizedDictionary.contains(token))
        .length;
    final romanizedRatio = tokens.isEmpty ? 0.0 : romanizedHits / tokens.length;

    final confidences = <DetectedLanguage, double>{
      DetectedLanguage.nepali: devanagariRatio,
      DetectedLanguage.english: latinRatio * (1 - romanizedRatio),
      DetectedLanguage.romanizedNepali:
          latinRatio * (romanizedRatio + _romanizedPatternScore(trimmed)),
      DetectedLanguage.mixed: 0,
      DetectedLanguage.unknown: letters == 0 ? 1 : 0,
    };

    if (devanagariRatio > 0.15 && latinRatio > 0.15) {
      confidences[DetectedLanguage.mixed] =
          (devanagariRatio + latinRatio) / 2 + romanizedRatio * 0.2;
    }

    final primary = confidences.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return LanguageDetectionResult(
      primaryLanguage:
          primary.value <= 0.05 ? DetectedLanguage.unknown : primary.key,
      confidences: confidences.map(
        (key, value) => MapEntry(key, value.clamp(0.0, 1.0)),
      ),
      devanagariRatio: devanagariRatio,
      latinRatio: latinRatio,
      romanizedDictionaryHits: romanizedHits,
    );
  }

  double _romanizedPatternScore(String input) {
    final normalized = TextUtils.normalizeLatin(input);
    final patterns = const [
      'cha',
      'chha',
      'lai',
      'sanga',
      'kaha',
      'kati',
      'jana',
      'basna',
      'chahiyo',
      'huncha',
      'bhayo',
    ];
    final hits = patterns.where(normalized.contains).length;
    return hits == 0 ? 0 : (hits / patterns.length).clamp(0.0, 0.35);
  }
}
