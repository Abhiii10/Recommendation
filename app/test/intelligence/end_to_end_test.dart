import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_response.dart';
import 'package:rural_tourism_app/features/intelligence/services/intelligence_orchestrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('emergency chatbot response bypasses online enhancement', () async {
    final orchestrator = IntelligenceOrchestrator();
    await orchestrator.initialize();

    final response = await orchestrator.respond(
      const ChatbotRequest(
        text: 'I am injured and need ambulance help',
        conversationId: 'emergency_test',
        allowOnlineEnhancement: true,
      ),
    );

    expect(response.isEmergency, isTrue);
    expect(response.intent, 'emergency_help');
    expect(response.source, ChatbotResponseSource.emergencyProtocol);
    expect(response.text, contains('Ambulance'));
    expect(response.metadata['contacts'], isNotEmpty);
  });
}
