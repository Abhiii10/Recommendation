import 'package:rural_tourism_app/features/intelligence/models/intent_classification_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/retrieved_context.dart';

enum ChatbotResponseSource {
  emergencyProtocol,
  offlineKnowledgeBase,
  offlineModel,
  onlineEnhancement,
  fallback,
}

class ChatbotResponse {
  final String text;
  final String intent;
  final double confidence;
  final bool isEmergency;
  final ChatbotResponseSource source;
  final LanguageDetectionResult? language;
  final IntentClassificationResult? intentResult;
  final List<RetrievedContext> retrievedContexts;
  final List<String> suggestions;
  final Map<String, dynamic> metadata;

  const ChatbotResponse({
    required this.text,
    required this.intent,
    required this.confidence,
    required this.isEmergency,
    required this.source,
    this.language,
    this.intentResult,
    this.retrievedContexts = const [],
    this.suggestions = const [],
    this.metadata = const {},
  });

  String get sourceLabel {
    switch (source) {
      case ChatbotResponseSource.emergencyProtocol:
        return 'Emergency protocol';
      case ChatbotResponseSource.offlineKnowledgeBase:
        return 'Offline knowledge base';
      case ChatbotResponseSource.offlineModel:
        return 'Offline AI model';
      case ChatbotResponseSource.onlineEnhancement:
        return 'Online enhancement';
      case ChatbotResponseSource.fallback:
        return 'Offline fallback';
    }
  }
}
