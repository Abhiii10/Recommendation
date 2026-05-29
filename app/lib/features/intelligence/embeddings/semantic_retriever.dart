import 'package:rural_tourism_app/features/intelligence/retrieval/retrieval_result.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_encoder.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_index.dart';

class SemanticRetriever {
  final EmbeddingEncoder encoder;
  final EmbeddingIndex index;

  const SemanticRetriever({
    required this.encoder,
    required this.index,
  });

  List<RetrievalResult> retrieve(String query, {int topK = 5}) {
    final vector = encoder.encode(query);
    return index
        .search(vector, topK: topK)
        .map(
          (match) => RetrievalResult(
            entry: match.entry,
            score: match.score,
            semanticScore: match.score,
            explanation: const {'retriever': 'semantic'},
          ),
        )
        .toList(growable: false);
  }
}
