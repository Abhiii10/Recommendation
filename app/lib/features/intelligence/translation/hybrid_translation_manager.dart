import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/translation/glossary_translator.dart';
import 'package:rural_tourism_app/features/intelligence/translation/neural_translation_adapter.dart';
import 'package:rural_tourism_app/features/intelligence/translation/phrasebook_translator.dart';
import 'package:rural_tourism_app/features/intelligence/translation/template_translator.dart';

class HybridTranslationManager {
  final PhrasebookTranslator phrasebookTranslator;
  final TemplateTranslator templateTranslator;
  final GlossaryTranslator glossaryTranslator;
  final NeuralTranslationAdapter neuralTranslationAdapter;

  const HybridTranslationManager({
    required this.phrasebookTranslator,
    required this.templateTranslator,
    required this.glossaryTranslator,
    required this.neuralTranslationAdapter,
  });

  Future<void> load() async {
    await Future.wait([
      phrasebookTranslator.load(),
      templateTranslator.load(),
      glossaryTranslator.load(),
      neuralTranslationAdapter.load(),
    ]);
  }

  /// Splits multi-sentence input (separated by . ! ? or newlines) into
  /// individual sentences so each one gets translated independently.
  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'(?<=[.!?\n])\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<TranslationResponse> translate(TranslationRequest request) async {
    await load();

    final sentences = _splitSentences(request.text);

    // If there are multiple sentences, translate each independently and join
    if (sentences.length > 1) {
      final results = <String>[];
      var allOffline = true;
      var lowestConfidence = 1.0;

      for (final sentence in sentences) {
        final subRequest = TranslationRequest(
          text: sentence,
          direction: request.direction,
          allowNeural: request.allowNeural,
        );
        final result = await _translateSingle(subRequest);
        if (result.translatedText.isNotEmpty) {
          results.add(result.translatedText);
        }
        if (!result.isOffline) allOffline = false;
        if (result.confidence < lowestConfidence) {
          lowestConfidence = result.confidence;
        }
      }

      if (results.isNotEmpty) {
        return TranslationResponse(
          translatedText: results.join('\n'),
          method: TranslationMethod.template,
          confidence: lowestConfidence,
          isOffline: allOffline,
        );
      }
    }

    return _translateSingle(request);
  }

  Future<TranslationResponse> _translateSingle(
      TranslationRequest request) async {
    // 1. Exact phrasebook match — always best for known tourism phrases
    final phrase = await phrasebookTranslator.translate(request);
    if (phrase != null && phrase.method == TranslationMethod.exactPhrasebook) {
      return phrase;
    }

    // 2. Template match — structured phrases with name/place slots
    final template = await templateTranslator.translate(request);
    if (template != null && template.confidence >= 0.80) return template;

    // 3. LLM neural translation (online) — for anything not in phrasebook
    if (request.allowNeural) {
      final neural = await neuralTranslationAdapter.translate(request);
      if (neural != null) return neural;
    }

    // 4. Glossary (offline fallback)
    final glossary = await glossaryTranslator.translate(request);
    if (glossary != null && glossary.confidence >= 0.50) return glossary;

    // 5. Fuzzy phrasebook match
    if (phrase != null) return phrase;

    return const TranslationResponse(
      translatedText: '',
      method: TranslationMethod.noResult,
      confidence: 0,
      isOffline: true,
      errorMessage:
          'No translation found. Connect to internet for AI translation.',
    );
  }
}