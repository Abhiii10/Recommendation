import '../models/dialogue_state.dart';
import '../models/nlp_processing_result.dart';
import '../models/rag_response.dart';
import '../models/retrieved_context.dart';
import 'context_retriever.dart';
import 'response_generator.dart';

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
    final retrievalResults = contextRetriever.retrieve(nlp, intent: intent);
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
      intent: intent,
      language: nlp.language,
      contexts: contexts,
      dialogueState: dialogueState,
    );
  }
}
