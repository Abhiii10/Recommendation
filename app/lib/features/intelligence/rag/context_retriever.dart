import '../models/nlp_processing_result.dart';
import '../retrieval/hybrid_retriever.dart';
import '../retrieval/retrieval_reranker.dart';
import '../retrieval/retrieval_result.dart';

class ContextRetriever {
  final HybridRetriever hybridRetriever;
  final RetrievalReranker reranker;

  const ContextRetriever({
    required this.hybridRetriever,
    required this.reranker,
  });

  List<RetrievalResult> retrieve(
    NlpProcessingResult nlp, {
    String? intent,
    int topK = 5,
  }) {
    final query = [
      nlp.normalizedText,
      nlp.romanizedNormalizedText,
      nlp.expandedTerms.join(' '),
    ].join(' ');
    final results = hybridRetriever.retrieve(query, topK: topK);
    return reranker.rerank(results, nlp, intent: intent);
  }
}
