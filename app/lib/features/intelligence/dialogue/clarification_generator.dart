import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';

class ClarificationGenerator {
  const ClarificationGenerator();

  String? generate({
    required String intent,
    required List<String> missingSlots,
    required double confidence,
    required LanguageDetectionResult language,
  }) {
    final nepali = language.languageCode == 'ne';
    if (confidence < 0.60) {
      return nepali
          ? 'मैले सही बुझिनँ जस्तो लाग्छ। तपाईं गन्तव्य, होमस्टे, खाना, यातायात वा सुरक्षा बारे सोध्दै हुनुहुन्छ?'
          : 'I am not fully sure I understood. Are you asking about destinations, homestays, food, transport, or safety?';
    }
    if (missingSlots.isEmpty) return null;
    switch (missingSlots.first) {
      case 'budget_level':
        return nepali
            ? 'उत्तम सुझाव दिन, तपाईंको अनुमानित बजेट कति हो?'
            : 'To give you the best recommendations, what is your approximate budget level?';
      case 'duration':
        return nepali
            ? 'यो यात्राको लागि तपाईंसँग कति दिन छ?'
            : 'How many days do you have for this trip?';
      case 'activity_type':
        return nepali
            ? 'तपाईंलाई कस्तो अनुभव मन पर्छ - साहस, संस्कृति, प्रकृति वा आराम?'
            : 'What type of experience interests you most: adventure, culture, nature, or relaxation?';
      case 'location':
        return nepali
            ? 'तपाईं कुन क्षेत्रमा वा गन्तव्यमा होमस्टे खोज्दै हुनुहुन्छ?'
            : 'Which area or destination should I search for homestays in?';
      default:
        return null;
    }
  }
}
