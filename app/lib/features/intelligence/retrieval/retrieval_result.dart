import 'package:rural_tourism_app/features/intelligence/models/knowledge_entry.dart';

class RetrievalResult {
  final KnowledgeEntry entry;
  final double score;
  final double semanticScore;
  final double lexicalScore;
  final Map<String, dynamic> explanation;

  const RetrievalResult({
    required this.entry,
    required this.score,
    this.semanticScore = 0,
    this.lexicalScore = 0,
    this.explanation = const {},
  });

  RetrievalResult copyWith({
    double? score,
    double? semanticScore,
    double? lexicalScore,
    Map<String, dynamic>? explanation,
  }) {
    return RetrievalResult(
      entry: entry,
      score: score ?? this.score,
      semanticScore: semanticScore ?? this.semanticScore,
      lexicalScore: lexicalScore ?? this.lexicalScore,
      explanation: explanation ?? this.explanation,
    );
  }
}
