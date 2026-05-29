import 'package:rural_tourism_app/features/intelligence/models/embedding_vector.dart';
import 'package:rural_tourism_app/features/intelligence/models/knowledge_entry.dart';
import 'package:rural_tourism_app/features/intelligence/utils/similarity_metrics.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_encoder.dart';

class EmbeddingIndex {
  final EmbeddingEncoder encoder;
  final _vectors = <String, EmbeddingVector>{};
  final _entries = <String, KnowledgeEntry>{};

  EmbeddingIndex({required this.encoder});

  void build(Iterable<KnowledgeEntry> entries) {
    _vectors.clear();
    _entries.clear();
    for (final entry in entries) {
      add(entry, encoder.encode(entry.searchableText));
    }
  }

  void add(KnowledgeEntry entry, EmbeddingVector vector) {
    _entries[entry.id] = entry;
    _vectors[entry.id] = vector;
  }

  List<EmbeddingMatch> search(EmbeddingVector query, {int topK = 5}) {
    final matches = <EmbeddingMatch>[];
    for (final entry in _entries.values) {
      final vector = _vectors[entry.id];
      if (vector == null) continue;
      final score = SimilarityMetrics.cosine(query.values, vector.values);
      matches.add(EmbeddingMatch(entry: entry, score: score));
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(topK).toList(growable: false);
  }
}

class EmbeddingMatch {
  final KnowledgeEntry entry;
  final double score;

  const EmbeddingMatch({required this.entry, required this.score});
}
