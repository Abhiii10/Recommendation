import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_request.dart';
import 'package:rural_tourism_app/features/intelligence/services/intelligence_orchestrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hybrid intent classifier recognizes core tourism intents', () async {
    final orchestrator = IntelligenceOrchestrator();
    await orchestrator.initialize();

    final cases = {
      'I need a homestay in Ghandruk tonight': 'homestay_search',
      'I want a cheap and peaceful village': 'budget_relaxation',
      'Is vegetarian food available?': 'vegetarian_food',
      'How do I reach Sikles from Pokhara?': 'transport_query',
      'What cultural etiquette should I follow?': 'culture_etiquette',
      'What should I know before trekking?': 'adventure_activity',
      'mardi': 'destination_query',
    };

    for (final entry in cases.entries) {
      final response = await orchestrator.respond(
        ChatbotRequest(text: entry.key, conversationId: 'intent_test'),
      );
      expect(
        response.intent,
        entry.value,
        reason: '"${entry.key}" should classify as ${entry.value}',
      );
      expect(response.confidence, greaterThan(0.45));
    }
  });
}
