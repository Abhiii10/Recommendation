import 'package:rural_tourism_app/features/intelligence/models/entity_mention.dart';
import 'package:rural_tourism_app/features/intelligence/models/intent_classification_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';
import 'package:rural_tourism_app/features/intelligence/intent/intent_classifier_base.dart';
import 'package:rural_tourism_app/features/intelligence/intent/intent_training_data.dart';
import 'package:rural_tourism_app/features/intelligence/intent/semantic_intent_classifier.dart';

class HybridIntentClassifier implements IntentClassifierBase {
  static const double _minimumIntentConfidence = 0.30;
  static const _trekkingTriggers = [
    'trekking',
    'trek',
    'hiking',
    'what to know',
    'tips',
    'safety',
    'prepare',
    'pack',
    'permit',
    'tims',
  ];
  static const _trekkingSafetyTerms = [
    'safe',
    'safety',
    'alone',
    'risk',
    'danger',
    'emergency',
  ];

  final SemanticIntentClassifier semanticClassifier;
  final Future<IntentTrainingData> Function() trainingDataLoader;

  IntentTrainingData? _trainingData;

  HybridIntentClassifier({
    required this.semanticClassifier,
    required this.trainingDataLoader,
  });

  @override
  Future<void> load() async {
    _trainingData = await trainingDataLoader();
    await semanticClassifier.load();
  }

  @override
  IntentClassificationResult classify(NlpProcessingResult nlp) {
    final destinationEntity = _destinationEntity(nlp);
    if (destinationEntity != null &&
        _shouldForceDestinationIntent(nlp, destinationEntity)) {
      return IntentClassificationResult(
        intent: 'destination_query',
        confidence: 0.95,
        alternatives: const {'destination_recommendation': 0.95},
        matchedFeatures: ['destination_gazetteer:${destinationEntity.text}'],
      );
    }

    final trekkingOverride = _trekkingIntentOverride(nlp);
    if (trekkingOverride != null) {
      return trekkingOverride;
    }

    final semantic = semanticClassifier.classify(nlp);
    final scores = <String, double>{};
    final features = <String>[];

    for (final entry in semantic.alternatives.entries) {
      scores[entry.key] = entry.value * 0.48;
    }
    if (semantic.intent != 'fallback') {
      features.add('semantic:${semantic.intent}');
    }

    for (final definition
        in _trainingData?.intents.values ?? const <IntentDefinition>[]) {
      final keywordScore = _keywordScore(nlp, definition);
      if (keywordScore > 0) {
        scores[definition.id] =
            (scores[definition.id] ?? 0) + keywordScore * 0.32;
        features.add('keyword:${definition.id}');
      }
      final ruleScore = _ruleScore(nlp, definition.id);
      if (ruleScore > 0) {
        scores[definition.id] = (scores[definition.id] ?? 0) + ruleScore * 0.20;
        features.add('rule:${definition.id}');
      }
    }

    if (_hasEntity(nlp, EntityType.destination)) {
      scores['destination_recommendation'] =
          (scores['destination_recommendation'] ?? 0) + 0.12;
      scores['route_navigation'] = (scores['route_navigation'] ?? 0) + 0.06;
    }
    if (_hasEntity(nlp, EntityType.money)) {
      scores['price_inquiry'] = (scores['price_inquiry'] ?? 0) + 0.14;
    }
    final normalizedText = TextUtils.normalizeSearchText(
      '${nlp.normalizedText} ${nlp.romanizedNormalizedText}',
    );
    if (normalizedText.contains('vegetarian') ||
        normalizedText.contains('vegan') ||
        normalizedText.contains('शाकाहारी')) {
      scores['vegetarian_food'] = (scores['vegetarian_food'] ?? 0) + 0.24;
      scores['food_query'] = (scores['food_query'] ?? 0) * 0.75;
    }
    if (_hasEntity(nlp, EntityType.duration)) {
      scores['destination_recommendation'] =
          (scores['destination_recommendation'] ?? 0) + 0.05;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value < _minimumIntentConfidence) {
      return const IntentClassificationResult(
        intent: 'fallback',
        confidence: 0,
        matchedFeatures: ['fallback'],
      );
    }

    final top = sorted.first;
    return IntentClassificationResult(
      intent: top.key,
      confidence: top.value.clamp(0.0, 1.0),
      alternatives: {
        for (final entry in sorted.take(5))
          entry.key: entry.value.clamp(0.0, 1.0),
      },
      matchedFeatures: features.take(8).toList(),
      isEmergency: top.key == 'emergency_help',
    );
  }

  double _keywordScore(NlpProcessingResult nlp, IntentDefinition definition) {
    if (definition.keywords.isEmpty) return 0.0;
    final queryTerms = {
      ...nlp.retrievalTerms.map(TextUtils.normalizeSearchText),
      TextUtils.normalizeSearchText(nlp.normalizedText),
      TextUtils.normalizeSearchText(nlp.romanizedNormalizedText),
    };
    var hits = 0;
    for (final keyword in definition.keywords) {
      final normalized = TextUtils.normalizeSearchText(keyword);
      if (normalized.isEmpty) continue;
      if (queryTerms
          .any((term) => term == normalized || term.contains(normalized))) {
        hits++;
      }
    }
    return (hits / definition.keywords.length).clamp(0.0, 1.0);
  }

  double _ruleScore(NlpProcessingResult nlp, String intent) {
    final text = TextUtils.normalizeSearchText(
      '${nlp.normalizedText} ${nlp.romanizedNormalizedText}',
    );
    bool hasAny(List<String> terms) => terms.any((term) => text.contains(term));

    switch (intent) {
      case 'general_greeting':
        return hasAny(['hello', 'hi', 'namaste', 'नमस्ते']) ? 0.95 : 0;
      case 'budget_relaxation':
        return hasAny(['cheap', 'budget', 'sasto', 'सस्तो']) &&
                hasAny(['peace', 'quiet', 'relax', 'shanta', 'शान्त'])
            ? 0.95
            : 0;
      case 'homestay_search':
        return hasAny(['homestay', 'hotel', 'room', 'stay', 'होमस्टे', 'बस्न'])
            ? 0.88
            : 0;
      case 'transport_query':
      case 'route_navigation':
        return hasAny(['bus', 'jeep', 'route', 'transport', 'reach', 'बाटो'])
            ? 0.84
            : 0;
      case 'vegetarian_food':
        return hasAny(['vegetarian', 'vegan', 'शाकाहारी', 'masu khanna'])
            ? 0.98
            : 0;
      case 'food_query':
        if (hasAny(['vegetarian', 'vegan', 'शाकाहारी'])) {
          return 0.35;
        }
        return hasAny(
                ['food', 'meal', 'khana', 'vegetarian', 'खाना', 'शाकाहारी'])
            ? 0.82
            : 0;
      case 'weather_season':
        return hasAny(
                ['season', 'weather', 'spring', 'autumn', 'monsoon', 'मौसम'])
            ? 0.82
            : 0;
      case 'emergency_help':
        return hasAny([
          'emergency',
          'sos',
          'help me',
          'police',
          'ambulance',
          'आपतकाल'
        ])
            ? 1.0
            : 0;
      case 'safety_concern':
        if (hasAny(['trek', 'trekking', 'hiking']) &&
            hasAny(['safe', 'safety', 'alone', 'risk', 'danger'])) {
          return 0.94;
        }
        return hasAny(['safe', 'safety', 'danger', 'risk', 'alone']) ? 0.86 : 0;
      case 'adventure_activity':
        if (hasAny(['trek', 'trekking', 'hiking']) &&
            hasAny([
              'tip',
              'tips',
              'advice',
              'bring',
              'pack',
              'preparation',
              'prepare',
              'before'
            ])) {
          return 0.94;
        }
        return hasAny(['trek', 'trekking', 'hiking', 'rafting', 'adventure'])
            ? 0.82
            : 0;
      default:
        return 0;
    }
  }

  bool _hasEntity(NlpProcessingResult nlp, EntityType type) =>
      nlp.entities.any((entity) => entity.type == type);

  IntentClassificationResult? _trekkingIntentOverride(
    NlpProcessingResult nlp,
  ) {
    final text = TextUtils.normalizeSearchText(
      '${nlp.normalizedText} ${nlp.romanizedNormalizedText}',
    );
    final matched = _trekkingTriggers.where(text.contains).toList();
    if (matched.isEmpty) return null;

    final safetyFocused = _trekkingSafetyTerms.any(text.contains);
    final intent = safetyFocused ? 'safety_concern' : 'adventure_activity';
    return IntentClassificationResult(
      intent: intent,
      confidence: 0.90,
      alternatives: {
        intent: 0.90,
        safetyFocused ? 'adventure_activity' : 'safety_concern': 0.72,
      },
      matchedFeatures: [
        'trekking_keyword:${matched.first}',
        if (safetyFocused) 'trekking_safety_override',
      ],
    );
  }

  EntityMention? _destinationEntity(NlpProcessingResult nlp) {
    final destinations =
        nlp.entities.where((entity) => entity.type == EntityType.destination);
    if (destinations.isEmpty) return null;
    return destinations.reduce(
      (best, entity) => entity.confidence > best.confidence ? entity : best,
    );
  }

  bool _shouldForceDestinationIntent(
    NlpProcessingResult nlp,
    EntityMention entity,
  ) {
    final text = TextUtils.normalizeSearchText(
      '${nlp.normalizedText} ${nlp.romanizedNormalizedText}',
    );
    final entityText = TextUtils.normalizeSearchText(entity.text);
    if (text.isEmpty || entityText.isEmpty) return false;
    if (text == entityText || text == '$entityText $entityText') return true;

    final blockers = [
      'homestay',
      'hotel',
      'room',
      'stay',
      'tonight',
      'booking',
      'route',
      'reach',
      'transport',
      'bus',
      'jeep',
      'taxi',
      'go to',
      'get to',
      'food',
      'eat',
      'price',
      'budget',
      'cheap',
      'safe',
      'safety',
    ];
    if (blockers.any(text.contains)) return false;

    final infoPatterns = [
      'tell me about',
      'information about',
      'info about',
      'about',
      'what is',
      'where is',
      'describe',
    ];
    return infoPatterns.any(text.contains);
  }
}
