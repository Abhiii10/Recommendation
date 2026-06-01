import 'package:rural_tourism_app/features/intelligence/core/intelligence_constants.dart';
import 'package:rural_tourism_app/features/intelligence/utils/json_loader.dart';

class IntentTrainingData {
  final Map<String, IntentDefinition> intents;

  const IntentTrainingData(this.intents);

  static Future<IntentTrainingData> load({JsonLoader? loader}) async {
    final jsonLoader = loader ?? JsonLoader();
    try {
      final decoded = await jsonLoader.loadMap(
        IntelligenceConstants.intentExamplesAsset,
      );
      final raw = decoded['intents'] as Map? ?? const {};
      return IntentTrainingData(
        raw.map(
          (key, value) => MapEntry(
            key.toString(),
            IntentDefinition.fromJson(
              key.toString(),
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        ),
      );
    } catch (_) {
      return IntentTrainingData(_fallbackIntents);
    }
  }

  static final _fallbackIntents = {
    'general_greeting': IntentDefinition(
      id: 'general_greeting',
      examples: const ['hello', 'hi', 'namaste', 'नमस्ते'],
      keywords: const ['hello', 'hi', 'namaste', 'नमस्ते'],
    ),
    'destination_recommendation': IntentDefinition(
      id: 'destination_recommendation',
      examples: const [
        'recommend a place',
        'where should I go',
        'mardi',
        'mardi himal',
        'tell me about mardi',
        'mardi trek',
        'information about mardi',
      ],
      keywords: const [
        'recommend',
        'destination',
        'place',
        'mardi',
        'mardi himal',
        'mardi trek',
        'गाउँ',
        'ठाउँ',
      ],
    ),
    'homestay_search': IntentDefinition(
      id: 'homestay_search',
      examples: const [
        'find a homestay',
        'where can I stay',
        'homestay near mardi',
        'where to stay in ghandruk',
        'cheap homestay',
      ],
      keywords: const [
        'homestay',
        'stay',
        'room',
        'hotel',
        'cheap homestay',
        'stay in ghandruk',
        'homestay near mardi',
        'होमस्टे',
      ],
    ),
    'adventure_activity': IntentDefinition(
      id: 'adventure_activity',
      examples: const [
        'what should I know before trekking',
        'trekking tips',
        'trekking advice',
        'what to bring for trekking',
        'trekking preparation',
        'what to pack for trek',
      ],
      keywords: const [
        'adventure',
        'trek',
        'trekking',
        'hiking',
        'tips',
        'advice',
        'bring',
        'pack',
        'preparation',
        'prepare',
      ],
    ),
    'safety_concern': IntentDefinition(
      id: 'safety_concern',
      examples: const [
        'what should I know before trekking',
        'trekking tips',
        'trekking advice',
        'what to bring for trekking',
        'trekking safety',
        'is it safe to trek alone',
        'trekking preparation',
        'what to pack for trek',
      ],
      keywords: const [
        'safe',
        'safety',
        'danger',
        'risk',
        'alone',
        'trekking tips',
        'trekking advice',
        'trekking safety',
        'trekking preparation',
        'what to pack for trek',
        'trek alone',
      ],
    ),
    'emergency_help': IntentDefinition(
      id: 'emergency_help',
      examples: const ['emergency', 'help me', 'मलाई सहयोग चाहियो'],
      keywords: const ['emergency', 'help', 'police', 'ambulance', 'आपतकाल'],
      priority: 'critical',
    ),
    'fallback': IntentDefinition(
      id: 'fallback',
      examples: const [],
      keywords: const [],
    ),
  };
}

class IntentDefinition {
  final String id;
  final List<String> examples;
  final List<String> keywords;
  final List<String> requiredSlots;
  final List<String> optionalSlots;
  final String? priority;

  const IntentDefinition({
    required this.id,
    required this.examples,
    required this.keywords,
    this.requiredSlots = const [],
    this.optionalSlots = const [],
    this.priority,
  });

  factory IntentDefinition.fromJson(String id, Map<String, dynamic> json) {
    List<String> list(dynamic value) {
      if (value is List) return value.map((item) => item.toString()).toList();
      if (value == null) return const [];
      return value
          .toString()
          .split('|')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return IntentDefinition(
      id: id,
      examples: [
        ...list(json['examples_en']),
        ...list(json['examples_ne']),
        ...list(json['examples_romanized']),
      ],
      keywords: list(json['keywords']),
      requiredSlots: list(json['slots_required']),
      optionalSlots: list(json['slots_optional']),
      priority: json['priority']?.toString(),
    );
  }
}
