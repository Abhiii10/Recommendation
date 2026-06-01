import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/rag_response.dart';
import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';
import 'package:rural_tourism_app/features/intelligence/rag/context_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/rag/response_generator.dart';

class RagPipeline {
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
    final effectiveIntent = _effectiveIntent(intent);
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
    if (intent == 'destination_query') return 'destination_recommendation';
    return intent;
  }
}
