import 'package:rural_tourism_app/features/intelligence/core/intelligence_config.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/services/intelligence_orchestrator.dart';

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
