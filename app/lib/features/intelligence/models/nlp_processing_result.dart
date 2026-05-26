import 'entity_mention.dart';
import 'language_detection_result.dart';

class NlpProcessingResult {
  final String originalText;
  final String normalizedText;
  final String romanizedNormalizedText;
  final LanguageDetectionResult language;
  final List<String> tokens;
  final List<String> stems;
  final List<String> contentTokens;
  final List<String> expandedTerms;
  final List<EntityMention> entities;
  final Map<String, dynamic> annotations;

  const NlpProcessingResult({
    required this.originalText,
    required this.normalizedText,
    required this.romanizedNormalizedText,
    required this.language,
    required this.tokens,
    required this.stems,
    required this.contentTokens,
    required this.expandedTerms,
    required this.entities,
    this.annotations = const {},
  });

  Set<String> get retrievalTerms => {
        ...contentTokens,
        ...stems,
        ...expandedTerms
      }.where((e) => e.isNotEmpty).toSet();
}
