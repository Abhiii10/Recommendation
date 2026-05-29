import 'package:rural_tourism_app/features/intelligence/models/chatbot_response.dart';
import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';
import 'package:rural_tourism_app/features/intelligence/safety/emergency_detector.dart';
import 'package:rural_tourism_app/features/intelligence/safety/emergency_response_repository.dart';

class SafetyLayer {
  final EmergencyDetector detector;
  final EmergencyResponseRepository responseRepository;

  const SafetyLayer({
    required this.detector,
    required this.responseRepository,
  });

  ChatbotResponse? check(String input, LanguageDetectionResult language) {
    final detection = detector.detect(input);
    if (!detection.isEmergency) return null;
    final response = responseRepository.responseFor(language);
    return ChatbotResponse(
      text: response.text,
      intent: 'emergency_help',
      confidence: detection.confidence,
      isEmergency: true,
      source: ChatbotResponseSource.emergencyProtocol,
      language: language,
      suggestions: const [
        'Call Tourist Police',
        'Call Ambulance',
        'Share location'
      ],
      metadata: {
        'matched_patterns': detection.matchedPatterns,
        'contacts': [
          for (final contact in response.contacts)
            {
              'type': contact.type,
              'number': contact.number,
              'name': contact.name,
            },
        ],
      },
    );
  }
}
