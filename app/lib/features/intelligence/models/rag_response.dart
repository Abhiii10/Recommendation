import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';

class RagResponse {
  final String text;
  final double confidence;
  final List<RetrievedContext> contexts;
  final String method;
  final List<String> suggestions;

  const RagResponse({
    required this.text,
    required this.confidence,
    required this.contexts,
    required this.method,
    this.suggestions = const [],
  });
}
