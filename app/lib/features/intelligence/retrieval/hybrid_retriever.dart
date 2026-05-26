import '../core/intelligence_config.dart';
import '../embeddings/semantic_retriever.dart';
import 'bm25_retriever.dart';
import 'retrieval_result.dart';

class HybridRetriever {
  final SemanticRetriever semanticRetriever;
  final BM25Retriever bm25Retriever;
  final IntelligenceConfig config;

  const HybridRetriever({
    required this.semanticRetriever,
    required this.bm25Retriever,
    this.config = IntelligenceConfig.production,
  });

  List<RetrievalResult> retrieve(String query, {int? topK}) {
    final limit = topK ?? config.retrievalTopK;
    final semantic = semanticRetriever.retrieve(query, topK: limit * 2);
    final lexical = bm25Retriever.retrieve(query, topK: limit * 2);
    final byId = <String, RetrievalResult>{};

    for (final result in semantic) {
      byId[result.entry.id] = result;
    }
    for (final result in lexical) {
      final existing = byId[result.entry.id];
      byId[result.entry.id] = RetrievalResult(
        entry: result.entry,
        score: 0,
        semanticScore: existing?.semanticScore ?? 0,
        lexicalScore: result.lexicalScore,
        explanation: {
          'semantic': existing?.semanticScore ?? 0,
          'lexical': result.lexicalScore,
        },
      );
    }

    final fused = byId.values.map((result) {
      final score = result.semanticScore * config.semanticWeight +
          result.lexicalScore * config.lexicalWeight;
      return result.copyWith(score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return fused.take(limit).toList(growable: false);
  }
}
