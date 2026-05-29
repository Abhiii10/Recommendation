import 'package:rural_tourism_app/features/intelligence/models/intent_classification_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';

abstract class IntentClassifierBase {
  Future<void> load();

  IntentClassificationResult classify(NlpProcessingResult nlp);
}
