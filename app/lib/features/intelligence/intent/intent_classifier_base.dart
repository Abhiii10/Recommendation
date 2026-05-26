import '../models/intent_classification_result.dart';
import '../models/nlp_processing_result.dart';

abstract class IntentClassifierBase {
  Future<void> load();

  IntentClassificationResult classify(NlpProcessingResult nlp);
}
