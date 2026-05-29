import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/retrieval_result.dart';

class RetrievalReranker {
  const RetrievalReranker();

  List<RetrievalResult> rerank(
    List<RetrievalResult> results,
    NlpProcessingResult nlp, {
    String? intent,
  }) {
    final reranked = results.map((result) {
      var boost = 0.0;
      if (intent != null && result.entry.intent == intent) boost += 0.12;
      for (final entity in nlp.entities) {
        if (entity.canonicalId != null &&
            result.entry.relatedDestinations.contains(entity.canonicalId)) {
          boost += 0.10;
        }
        if (result.entry.searchableText
            .toLowerCase()
            .contains(entity.text.toLowerCase())) {
          boost += 0.06;
        }
      }
      return result.copyWith(score: (result.score + boost).clamp(0.0, 1.0));
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return reranked;
  }
}
