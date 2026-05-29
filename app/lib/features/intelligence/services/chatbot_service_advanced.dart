import 'package:rural_tourism_app/features/intelligence/core/intelligence_config.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_response.dart';
import 'package:rural_tourism_app/features/intelligence/services/intelligence_orchestrator.dart';

class ChatbotServiceAdvanced {
  final IntelligenceOrchestrator orchestrator;

  ChatbotServiceAdvanced(
      {IntelligenceConfig config = IntelligenceConfig.production})
      : orchestrator = IntelligenceOrchestrator(config: config);

  Future<void> init() => orchestrator.initialize();

  Future<ChatbotResponse> respond({
    required String text,
    required String conversationId,
    bool allowOnlineEnhancement = true,
    String? preferredLanguageCode,
  }) {
    return orchestrator.respond(
      ChatbotRequest(
        text: text,
        conversationId: conversationId,
        allowOnlineEnhancement: allowOnlineEnhancement,
        preferredLanguageCode: preferredLanguageCode,
      ),
    );
  }
}
