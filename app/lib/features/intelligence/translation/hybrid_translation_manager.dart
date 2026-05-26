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
    final phrase = await phrasebookTranslator.translate(request);
    if (phrase != null && phrase.method == TranslationMethod.exactPhrasebook) {
      return phrase;
    }

    final template = await templateTranslator.translate(request);
    if (template != null) return template;

    final glossary = await glossaryTranslator.translate(request);
    if (glossary != null && glossary.confidence >= 0.55) return glossary;

    final neural = await neuralTranslationAdapter.translate(request);
    if (neural != null) return neural;

    if (phrase != null) return phrase;

    return const TranslationResponse(
      translatedText: '',
      method: TranslationMethod.noResult,
      confidence: 0,
      isOffline: true,
      errorMessage:
          'No offline translation match. Try a simpler tourism phrase or use online fallback.',
    );
  }
}
