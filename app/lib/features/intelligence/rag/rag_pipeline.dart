import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/rag_response.dart';
import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';
import 'package:rural_tourism_app/features/intelligence/rag/context_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/rag/response_generator.dart';

class RagPipeline {
  static const _trekkingTriggers = [
    'trekking',
    'trek',
    'hiking',
    'what to know',
    'tips',
    'safety',
    'prepare',
    'pack',
    'permit',
    'tims',
  ];
  static const _safetyTriggers = [
    'safe',
    'safety',
    'alone',
    'risk',
    'danger',
    'emergency',
  ];

  final ContextRetriever contextRetriever;
  final ResponseGenerator responseGenerator;

  const RagPipeline({
    required this.contextRetriever,
    required this.responseGenerator,
  });

  RagResponse run({
    required NlpProcessingResult nlp,
    required String intent,
    required DialogueState dialogueState,
  }) {
    final trekkingIntent = _trekkingIntentForText(nlp);
    final effectiveIntent =
        trekkingIntent.isNotEmpty ? trekkingIntent : _effectiveIntent(intent);
    final retrievalResults = contextRetriever.retrieve(
      nlp,
      intent: effectiveIntent,
    );
    final contexts = retrievalResults
        .map(
          (result) => RetrievedContext(
            entry: result.entry,
            score: result.score,
            semanticScore: result.semanticScore,
            lexicalScore: result.lexicalScore,
            source: 'hybrid_retrieval',
            explanation: result.explanation,
          ),
        )
        .toList(growable: false);
    return responseGenerator.generate(
      intent: effectiveIntent,
      language: nlp.language,
      contexts: contexts,
      dialogueState: dialogueState,
    );
  }

  String _effectiveIntent(String intent) {
    if (intent == 'trekking_info') return 'adventure_activity';
    if (intent == 'safety_info') return 'safety_concern';
    if (intent == 'homestay_query') return 'homestay_search';
    if (intent == 'destination_query') return 'destination_recommendation';
    return intent;
  }

  String _trekkingIntentForText(NlpProcessingResult nlp) {
    final text = [
      nlp.normalizedText,
      nlp.romanizedNormalizedText,
      nlp.expandedTerms.join(' '),
    ].join(' ').toLowerCase();
    if (!_trekkingTriggers.any(text.contains)) {
      return '';
    }
    return _safetyTriggers.any(text.contains) ? 'safety_info' : 'trekking_info';
  }
}
