import '../core/intelligence_config.dart';
import '../models/chatbot_request.dart';
import '../models/chatbot_response.dart';
import 'intelligence_orchestrator.dart';

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
