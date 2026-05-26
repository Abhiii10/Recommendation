import '../embeddings/embedding_encoder.dart';
import '../models/intent_classification_result.dart';
import '../models/nlp_processing_result.dart';
import '../utils/similarity_metrics.dart';
import 'intent_classifier_base.dart';
import 'intent_training_data.dart';

class SemanticIntentClassifier implements IntentClassifierBase {
  final EmbeddingEncoder encoder;
  final Future<IntentTrainingData> Function() trainingDataLoader;

  IntentTrainingData? _trainingData;
  final _exampleVectors = <String, List<List<double>>>{};

  SemanticIntentClassifier({
    required this.encoder,
    required this.trainingDataLoader,
  });

  @override
  Future<void> load() async {
    _trainingData ??= await trainingDataLoader();
    _exampleVectors.clear();
    for (final entry in _trainingData!.intents.entries) {
      _exampleVectors[entry.key] = entry.value.examples
          .map((example) => encoder.encode(example).values)
          .toList(growable: false);
    }
  }

  @override
  IntentClassificationResult classify(NlpProcessingResult nlp) {
    final query = encoder.encode(nlp.normalizedText).values;
    final scores = <String, double>{};
    for (final entry in _exampleVectors.entries) {
      var best = 0.0;
      for (final vector in entry.value) {
        final score = SimilarityMetrics.cosine(query, vector);
        if (score > best) best = score;
      }
      scores[entry.key] = best;
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value < 0.15) {
      return const IntentClassificationResult(
        intent: 'fallback',
        confidence: 0,
      );
    }
    return IntentClassificationResult(
      intent: sorted.first.key,
      confidence: sorted.first.value.clamp(0.0, 1.0),
      alternatives: {
        for (final entry in sorted.take(5)) entry.key: entry.value,
      },
      matchedFeatures: const ['semantic_examples'],
      isEmergency: sorted.first.key == 'emergency_help',
    );
  }
}
