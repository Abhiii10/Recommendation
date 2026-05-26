import '../core/intelligence_config.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart';
import 'intelligence_orchestrator.dart';

class TranslationServiceAdvanced {
  final IntelligenceOrchestrator orchestrator;

  TranslationServiceAdvanced(
      {IntelligenceConfig config = IntelligenceConfig.production})
      : orchestrator = IntelligenceOrchestrator(config: config);

  Future<void> init() => orchestrator.initialize();

  Future<TranslationResponse> translate(TranslationRequest request) {
    return orchestrator.translate(request);
  }
}
