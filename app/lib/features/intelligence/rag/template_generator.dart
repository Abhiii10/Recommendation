import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';
import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';

class TemplateGenerator {
  const TemplateGenerator();

  String generate({
    required String intent,
    required LanguageDetectionResult language,
    required List<RetrievedContext> contexts,
    required DialogueState state,
  }) {
    final nepali = language.languageCode == 'ne';
    if (contexts.isEmpty) {
      return nepali
          ? 'मैले यस प्रश्नको लागि ठ्याक्कै मिल्ने जानकारी भेटिनँ। गन्तव्य, होमस्टे, खाना, यातायात वा सुरक्षा बारे फेरि सोध्नुहोस्।'
          : 'I could not find an exact match for that. Try asking about destinations, homestays, food, transport, safety, or cultural tips.';
    }

    if (intent == 'general_greeting') {
      return nepali
          ? 'नमस्ते! म ग्रामीण नेपाल पर्यटन सहायक हुँ। गन्तव्य, होमस्टे, खाना, यातायात र सुरक्षा बारे अफलाइन मद्दत गर्न सक्छु।'
          : 'Hello! I am your rural Nepal tourism assistant. I can help offline with destinations, homestays, food, transport, and safety.';
    }

    final top = contexts.take(3).toList();
    final buffer = StringBuffer();
    if (top.length == 1) {
      buffer.writeln(top.first.entry.textForLanguage(language.languageCode));
    } else {
      buffer.writeln(
        nepali
            ? 'तपाईंको प्रश्नसँग मिल्ने मुख्य जानकारी:'
            : 'Here is the most relevant information I found:',
      );
      buffer.writeln();
      for (final context in top) {
        buffer.writeln(
          '- ${context.entry.textForLanguage(language.languageCode)}',
        );
      }
    }
    final filledSlots = state.slots.values
        .where((slot) => slot.value != null)
        .map((slot) => '${slot.name}: ${slot.value}')
        .join(', ');
    if (filledSlots.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        nepali
            ? 'तपाईंको रुचि ध्यानमा राखियो: $filledSlots.'
            : 'I used your stated preferences: $filledSlots.',
      );
    }
    return buffer.toString().trim();
  }
}
