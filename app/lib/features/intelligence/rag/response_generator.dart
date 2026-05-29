import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';
import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/rag_response.dart';
import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';
import 'package:rural_tourism_app/features/intelligence/rag/template_generator.dart';

class ResponseGenerator {
  final TemplateGenerator templateGenerator;

  const ResponseGenerator({required this.templateGenerator});

  RagResponse generate({
    required String intent,
    required LanguageDetectionResult language,
    required List<RetrievedContext> contexts,
    required DialogueState dialogueState,
  }) {
    final text = templateGenerator.generate(
      intent: intent,
      language: language,
      contexts: contexts,
      state: dialogueState,
    );
    final confidence =
        contexts.isEmpty ? 0.35 : contexts.first.score.clamp(0.0, 1.0);
    return RagResponse(
      text: text,
      confidence: confidence,
      contexts: contexts,
      method: 'template_rag',
      suggestions: _suggestionsForIntent(intent),
    );
  }

  List<String> _suggestionsForIntent(String intent) {
    switch (intent) {
      case 'destination_recommendation':
      case 'budget_relaxation':
        return const ['Show on map', 'Find homestay nearby', 'Best season'];
      case 'homestay_search':
        return const ['Call host', 'Get directions', 'Ask about food'];
      case 'emergency_help':
        return const [
          'Call Tourist Police',
          'Call Ambulance',
          'Share location'
        ];
      case 'food_query':
      case 'vegetarian_food':
        return const ['Vegetarian food', 'Dal bhat', 'Local etiquette'];
      default:
        return const ['Recommend a place', 'Find a homestay', 'Safety tips'];
    }
  }
}
