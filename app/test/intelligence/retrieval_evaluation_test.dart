import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_encoder.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_index.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/semantic_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/bm25_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/hybrid_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hybrid retrieval returns relevant homestay context in top 5', () async {
    final repository = KnowledgeRepository();
    await repository.load();
    final encoder = const EmbeddingEncoder();
    final index = EmbeddingIndex(encoder: encoder)..build(repository.entries);
    final bm25 = BM25Retriever()..build(repository.entries);
    final retriever = HybridRetriever(
      semanticRetriever: SemanticRetriever(encoder: encoder, index: index),
      bm25Retriever: bm25,
    );

    final results = retriever.retrieve('book homestay in village', topK: 5);

    expect(results, isNotEmpty);
    expect(
      results.any((result) => result.entry.intent == 'homestay_search'),
      isTrue,
    );
  });
}
