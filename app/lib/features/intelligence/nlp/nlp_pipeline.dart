import '../models/nlp_processing_result.dart';
import '../utils/cache_manager.dart';
import 'advanced_tokenizer.dart';
import 'devanagari_normalizer.dart';
import 'language_detector.dart';
import 'named_entity_recognizer.dart';
import 'nepali_stemmer.dart';
import 'romanized_nepali_normalizer.dart';
import 'stopword_remover.dart';
import 'synonym_expander.dart';

class NlpPipeline {
  final LanguageDetector languageDetector;
  final DevanagariNormalizer devanagariNormalizer;
  final RomanizedNepaliNormalizer romanizedNormalizer;
  final AdvancedTokenizer tokenizer;
  final NepaliStemmer stemmer;
  final StopwordRemover stopwordRemover;
  final NamedEntityRecognizer namedEntityRecognizer;
  final SynonymExpander synonymExpander;
  final IntelligenceCacheManager cache;

  NlpPipeline({
    required this.languageDetector,
    required this.devanagariNormalizer,
    required this.romanizedNormalizer,
    required this.tokenizer,
    required this.stemmer,
    required this.stopwordRemover,
    required this.namedEntityRecognizer,
    required this.synonymExpander,
    IntelligenceCacheManager? cache,
  }) : cache = cache ?? IntelligenceCacheManager(maxEntries: 256);

  NlpProcessingResult process(String text) {
    final cached = cache.get<NlpProcessingResult>(text);
    if (cached != null) return cached;

    final language = languageDetector.detect(text);
    final normalized = devanagariNormalizer.normalize(text);
    final romanizedNormalized = romanizedNormalizer.normalize(text);
    final tokens = tokenizer.tokenize(normalized);
    final stems = stemmer.stemAll(tokens);
    final contentTokens = stopwordRemover.remove(stems);
    final expandedTerms = synonymExpander.expand(contentTokens).toList();
    final entities = namedEntityRecognizer.recognize(normalized);

    final result = NlpProcessingResult(
      originalText: text,
      normalizedText: normalized,
      romanizedNormalizedText: romanizedNormalized,
      language: language,
      tokens: tokens,
      stems: stems,
      contentTokens: contentTokens,
      expandedTerms: expandedTerms,
      entities: entities,
      annotations: {
        'token_count': tokens.length,
        'content_token_count': contentTokens.length,
      },
    );
    cache.set(text, result);
    return result;
  }
}
