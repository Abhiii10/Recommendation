import 'package:rural_tourism_app/features/intelligence/models/knowledge_entry.dart';

class RetrievedContext {
  final KnowledgeEntry entry;
  final double score;
  final double semanticScore;
  final double lexicalScore;
  final String source;
  final Map<String, dynamic> explanation;

  const RetrievedContext({
    required this.entry,
    required this.score,
    required this.semanticScore,
    required this.lexicalScore,
    required this.source,
    this.explanation = const {},
  });
}
