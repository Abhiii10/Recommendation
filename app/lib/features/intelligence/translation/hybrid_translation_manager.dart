import '../models/translation_request.dart';
import '../models/translation_response.dart';
import 'glossary_translator.dart';
import 'neural_translation_adapter.dart';
import 'phrasebook_translator.dart';
import 'template_translator.dart';

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

  Future<TranslationResponse> translate(TranslationRequest request) async {
    await load();

    // 1. Exact phrasebook match — always best for known tourism phrases
    final phrase = await phrasebookTranslator.translate(request);
    if (phrase != null && phrase.method == TranslationMethod.exactPhrasebook) {
      return phrase;
    }

    // 2. Template match — structured phrases
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
