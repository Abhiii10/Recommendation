import 'dart:math' as math;

import 'package:rural_tourism_app/features/intelligence/models/knowledge_entry.dart';
import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/retrieval_result.dart';

class BM25Retriever {
  final double k1;
  final double b;
  final _documents = <_Bm25Document>[];
  final _idf = <String, double>{};
  double _averageLength = 0;

  BM25Retriever({this.k1 = 1.5, this.b = 0.75});

  void build(Iterable<KnowledgeEntry> entries) {
    _documents.clear();
    _idf.clear();
    final documentFrequency = <String, int>{};

    for (final entry in entries) {
      final tokens = TextUtils.simpleTokens(entry.searchableText);
      final frequencies = <String, int>{};
      for (final token in tokens) {
        frequencies[token] = (frequencies[token] ?? 0) + 1;
      }
      for (final token in frequencies.keys) {
        documentFrequency[token] = (documentFrequency[token] ?? 0) + 1;
      }
      _documents.add(
        _Bm25Document(
            entry: entry, frequencies: frequencies, length: tokens.length),
      );
    }

    _averageLength = _documents.isEmpty
        ? 0
        : _documents.map((doc) => doc.length).reduce((a, b) => a + b) /
            _documents.length;
    final total = _documents.length;
    for (final entry in documentFrequency.entries) {
      _idf[entry.key] =
          math.log(1 + (total - entry.value + 0.5) / (entry.value + 0.5));
    }
  }

  List<RetrievalResult> retrieve(String query, {int topK = 5}) {
    final queryTokens = TextUtils.simpleTokens(query).toSet();
    if (queryTokens.isEmpty || _documents.isEmpty) return const [];
    final scored = <RetrievalResult>[];

    for (final document in _documents) {
      var score = 0.0;
      for (final token in queryTokens) {
        final termFrequency = document.frequencies[token] ?? 0;
        if (termFrequency == 0) continue;
        final idf = _idf[token] ?? 0.0;
        final numerator = termFrequency * (k1 + 1);
        final denominator = termFrequency +
            k1 * (1 - b + b * document.length / math.max(_averageLength, 1));
        score += idf * numerator / denominator;
      }
      if (score > 0) {
        scored.add(
          RetrievalResult(
            entry: document.entry,
            score: score,
            lexicalScore: score,
            explanation: const {'retriever': 'bm25'},
          ),
        );
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final maxScore = scored.isEmpty ? 1.0 : scored.first.score;
    return scored
        .take(topK)
        .map(
          (result) => result.copyWith(
            score: result.score / maxScore,
            lexicalScore: result.lexicalScore / maxScore,
          ),
        )
        .toList(growable: false);
  }
}

class _Bm25Document {
  final KnowledgeEntry entry;
  final Map<String, int> frequencies;
  final int length;

  const _Bm25Document({
    required this.entry,
    required this.frequencies,
    required this.length,
  });
}
