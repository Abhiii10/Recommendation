import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/haversine.dart';
import '../features/intelligence/models/chatbot_response.dart' as intelligence;
import '../features/intelligence/safety/emergency_detector.dart';
import '../features/intelligence/services/chatbot_service_advanced.dart';
import '../models/chat_message.dart';
import '../models/destination.dart';

const double _fallbackThreshold = 0.12;
const double _mediumConfidenceThreshold = 0.24;

class ChatbotService {
  final List<Destination> destinations;
  final ChatbotServiceAdvanced _advanced = ChatbotServiceAdvanced();

  late final Map<String, dynamic> _knowledgeBase;
  late final Map<String, dynamic> _responses;
  late final Map<String, List<String>> _intentTerms;
  late final Map<String, double> _intentWeights;
  late final Map<String, Destination> _aliasToDestination;

  bool _ready = false;

  ChatbotService({
    required this.destinations,
  });

  Future<void> init() async {
    if (_ready) return;

    final raw = await rootBundle.loadString(
      'assets/data/chatbot_knowledge_base.json',
    );

    _knowledgeBase = jsonDecode(raw) as Map<String, dynamic>;
    _responses = Map<String, dynamic>.from(
      (_knowledgeBase['responses'] as Map?) ?? const {},
    );

    _intentTerms = {};
    _intentWeights = {};

    final intents = Map<String, dynamic>.from(
      (_knowledgeBase['intents'] as Map?) ?? const {},
    );

    for (final entry in intents.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);

      final keywords = _readStringList(data['keywords']);
      final examples = _readStringList(data['examples']);

      _intentTerms[entry.key] = [
        ...keywords,
        ...examples,
      ];

      _intentWeights[entry.key] = (data['weight'] as num?)?.toDouble() ?? 1.0;
    }

    _aliasToDestination = _buildDestinationAliasMap();
    await _advanced.init();
    _ready = true;
  }

  ChatMessage greetingMessage() {
    return ChatMessage.fromBot(
      _randomResponse('greeting'),
      detectedIntent: 'greeting',
      confidence: 1.0,
    );
  }

  ChatMessage respond(String userText) {
    assert(_ready, 'Call init() before respond().');

    final normalizedInput = _normalize(userText);

    if (normalizedInput.isEmpty) {
      return ChatMessage.fromBot(
        _response('fallback'),
        detectedIntent: 'fallback',
        confidence: 0.0,
      );
    }

    final slots = _extractSlots(normalizedInput);
    final classification = _classifyIntent(normalizedInput, slots);

    final response = _buildResponse(
      input: normalizedInput,
      intent: classification.intent,
      confidence: classification.confidence,
      slots: slots,
    );

    return ChatMessage.fromBot(
      response,
      detectedIntent: classification.intent,
      confidence: classification.confidence,
    );
  }

  Future<ChatMessage> respondAdvanced(
    String userText, {
    bool allowOnlineEnhancement = true,
  }) async {
    if (!_ready) await init();
    final response = await _advanced.respond(
      text: userText,
      conversationId: 'chatbot_screen',
      allowOnlineEnhancement: allowOnlineEnhancement,
    );
    return _chatMessageFromAdvanced(response);
  }

  bool isEmergencyLike(String userText) {
    return const EmergencyDetector().detect(userText).isEmergency;
  }

  List<QuickSuggestion> suggestionsFromAdvanced(ChatMessage message) {
    if (message.advancedSuggestions.isEmpty) {
      return suggestionsForIntent(message.detectedIntent ?? 'fallback');
    }
    return message.advancedSuggestions
        .map(
          (label) => QuickSuggestion(
            label,
            icon: _iconForSuggestion(label),
            message: _messageForSuggestion(label),
          ),
        )
        .toList(growable: false);
  }

  ChatMessage _chatMessageFromAdvanced(intelligence.ChatbotResponse response) {
    return ChatMessage.fromBot(
      response.text,
      detectedIntent: response.intent,
      confidence: response.confidence,
      responseMode: response.source ==
              intelligence.ChatbotResponseSource.onlineEnhancement
          ? ChatResponseMode.onlineLlm
          : ChatResponseMode.offlineFallback,
      isEmergency: response.isEmergency,
      responseSourceLabel: response.sourceLabel,
      detectedLanguageLabel: response.language?.primaryLanguage.name,
      advancedSuggestions: response.suggestions,
      metadata: response.metadata,
    );
  }

  IconData _iconForSuggestion(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('map') || lower.contains('direction')) {
      return Icons.map_rounded;
    }
    if (lower.contains('call')) return Icons.call_rounded;
    if (lower.contains('homestay')) return Icons.hotel_rounded;
    if (lower.contains('season')) return Icons.calendar_month_rounded;
    if (lower.contains('safety') || lower.contains('police')) {
      return Icons.health_and_safety_rounded;
    }
    if (lower.contains('food')) return Icons.restaurant_rounded;
    return Icons.auto_awesome_rounded;
  }

  String _messageForSuggestion(String label) {
    switch (label) {
      case 'Show on map':
        return 'Show this destination on the map';
      case 'Find homestay nearby':
        return 'Find homestays nearby';
      case 'Call Tourist Police':
        return 'I need tourist police help';
      case 'Call Ambulance':
        return 'I need an ambulance';
      case 'Share location':
        return 'How can I share my location?';
      default:
        return label;
    }
  }

  String debugDetectIntent(String userText) {
    final normalizedInput = _normalize(userText);
    final slots = _extractSlots(normalizedInput);
    return _classifyIntent(normalizedInput, slots).intent;
  }

  double debugIntentConfidence(String userText) {
    final normalizedInput = _normalize(userText);
    final slots = _extractSlots(normalizedInput);
    return _classifyIntent(normalizedInput, slots).confidence;
  }

  List<QuickSuggestion> initialSuggestions() {
    return const [
      QuickSuggestion(
        'Best season',
        icon: Icons.calendar_month_rounded,
        message: 'When is the best time to visit rural Nepal?',
      ),
      QuickSuggestion(
        'Trekking',
        icon: Icons.hiking_rounded,
        message: 'What should I know before trekking?',
      ),
      QuickSuggestion(
        'Homestays',
        icon: Icons.hotel_rounded,
        message: 'Tell me about homestays in rural villages',
      ),
      QuickSuggestion(
        'Budget',
        icon: Icons.payments_rounded,
        message: 'How much budget do I need per day?',
      ),
      QuickSuggestion(
        'Culture',
        icon: Icons.account_balance_rounded,
        message: 'What cultural etiquette should I follow?',
      ),
      QuickSuggestion(
        'Transport',
        icon: Icons.directions_bus_rounded,
        message: 'How do I travel from Pokhara to nearby villages?',
      ),
    ];
  }

  List<QuickSuggestion> suggestionsForIntent(String intent) {
    switch (intent) {
      case 'best_time_to_visit':
        return const [
          QuickSuggestion(
            'Spring',
            icon: Icons.hiking_rounded,
            message: 'Is spring a good season for trekking?',
          ),
          QuickSuggestion(
            'Monsoon',
            icon: Icons.calendar_month_rounded,
            message: 'Is it safe to travel during monsoon?',
          ),
          QuickSuggestion(
            'Autumn',
            icon: Icons.calendar_month_rounded,
            message: 'Why is autumn good for rural tourism?',
          ),
        ];

      case 'transport':
        return const [
          QuickSuggestion(
            'From Pokhara',
            icon: Icons.directions_bus_rounded,
            message: 'How do I travel from Pokhara to rural villages?',
          ),
          QuickSuggestion(
            'Local bus',
            icon: Icons.directions_bus_rounded,
            message: 'Can I use local buses to reach villages?',
          ),
          QuickSuggestion(
            'Jeep',
            icon: Icons.directions_bus_rounded,
            message: 'Is jeep travel better than bus?',
          ),
        ];

      case 'homestay':
        return const [
          QuickSuggestion(
            'Price',
            icon: Icons.hotel_rounded,
            message: 'How much does a homestay usually cost?',
          ),
          QuickSuggestion(
            'Family stay',
            icon: Icons.hotel_rounded,
            message: 'Are homestays good for families?',
          ),
          QuickSuggestion(
            'Food',
            icon: Icons.hotel_rounded,
            message: 'What food is available in homestays?',
          ),
        ];

      case 'safety':
      case 'emergency_help':
        return const [
          QuickSuggestion(
            'Emergency',
            icon: Icons.health_and_safety_rounded,
            message: 'What should I do in an emergency?',
          ),
          QuickSuggestion(
            'Solo travel',
            icon: Icons.health_and_safety_rounded,
            message: 'Is it safe to travel alone?',
          ),
          QuickSuggestion(
            'Monsoon safety',
            icon: Icons.hiking_rounded,
            message: 'Is trekking safe during monsoon?',
          ),
        ];

      case 'budget':
        return const [
          QuickSuggestion(
            'Daily cost',
            icon: Icons.payments_rounded,
            message: 'What is the daily cost for rural tourism?',
          ),
          QuickSuggestion(
            'Budget places',
            icon: Icons.payments_rounded,
            message: 'Recommend budget friendly destinations',
          ),
          QuickSuggestion(
            'Cash',
            icon: Icons.payments_rounded,
            message: 'Do I need cash in rural villages?',
          ),
        ];

      case 'trekking':
        return const [
          QuickSuggestion(
            'Packing',
            icon: Icons.hiking_rounded,
            message: 'What should I pack for trekking?',
          ),
          QuickSuggestion(
            'Permits',
            icon: Icons.hiking_rounded,
            message: 'What permits do I need for trekking?',
          ),
          QuickSuggestion(
            'Beginner trek',
            icon: Icons.hiking_rounded,
            message: 'Which trekking routes are good for beginners?',
          ),
        ];

      case 'fallback':
        return const [
          QuickSuggestion(
            'Best season',
            icon: Icons.calendar_month_rounded,
            message: 'What is the best season to visit Ghandruk?',
          ),
          QuickSuggestion(
            'Safety',
            icon: Icons.hiking_rounded,
            message: 'Is trekking safe during monsoon?',
          ),
          QuickSuggestion(
            'Transport',
            icon: Icons.directions_bus_rounded,
            message: 'How do I reach Sikles from Pokhara?',
          ),
          QuickSuggestion(
            'Homestay',
            icon: Icons.hotel_rounded,
            message: 'Where can I stay in a rural village?',
          ),
          QuickSuggestion(
            'Recommend',
            icon: Icons.auto_awesome_rounded,
            message: 'Recommend me a peaceful village',
          ),
        ];

      default:
        return const [
          QuickSuggestion(
            'Nearby',
            icon: Icons.map_rounded,
            message: 'What places are nearby?',
          ),
          QuickSuggestion(
            'Recommend',
            icon: Icons.auto_awesome_rounded,
            message: 'Recommend me a place to visit',
          ),
          QuickSuggestion(
            'Offline help',
            icon: Icons.offline_bolt_rounded,
            message: 'Can I use this app without internet?',
          ),
        ];
    }
  }

  _IntentClassification _classifyIntent(
    String input,
    Map<String, dynamic> slots,
  ) {
    final destination = slots['destination'] as Destination?;
    final scores = <String, double>{};

    for (final intent in _intentTerms.keys) {
      if (intent == 'fallback') continue;
      scores[intent] = _scoreIntent(input, intent);
    }

    if (_isEmergencyQuestion(input)) {
      return const _IntentClassification(
        intent: 'emergency_help',
        confidence: 1.0,
      );
    }

    if (_isSafetyQuestion(input)) {
      scores['safety'] = max(scores['safety'] ?? 0.0, 0.58);
    }

    if (_isRecommendationQuestion(input)) {
      scores['recommendation_help'] =
          max(scores['recommendation_help'] ?? 0.0, 0.62);
    }

    if (_containsAny(input, const [
      'best time',
      'season',
      'weather',
      'when',
      'month',
      'spring',
      'autumn',
      'winter',
      'monsoon',
      'rainy',
      'visit during',
    ])) {
      scores['best_time_to_visit'] =
          max(scores['best_time_to_visit'] ?? 0.0, 0.64);
    }

    if (_containsAny(input, const [
      'stay',
      'homestay',
      'homestays',
      'hotel',
      'room',
      'sleep',
      'accommodation',
      'lodging',
    ])) {
      scores['homestay'] = max(scores['homestay'] ?? 0.0, 0.63);
    }

    if (destination != null) {
      scores['destination_info'] = max(scores['destination_info'] ?? 0.0, 0.50);

      if (_containsAny(input, const [
        'best time',
        'season',
        'weather',
        'when',
        'month',
        'spring',
        'autumn',
        'winter',
        'monsoon',
      ])) {
        scores['best_time_to_visit'] =
            max(scores['best_time_to_visit'] ?? 0.0, 0.62);
      }

      if (_containsAny(input, const [
        'how to get',
        'reach',
        'transport',
        'bus',
        'jeep',
        'route',
        'from pokhara',
        'go to',
      ])) {
        scores['transport'] = max(scores['transport'] ?? 0.0, 0.62);
      }

      if (_containsAny(input, const [
        'stay',
        'homestay',
        'hotel',
        'room',
        'sleep',
        'accommodation',
      ])) {
        scores['homestay'] = max(scores['homestay'] ?? 0.0, 0.60);
      }

      if (_containsAny(input, const [
        'cost',
        'budget',
        'price',
        'cheap',
        'expensive',
        'money',
        'how much',
      ])) {
        scores['budget'] = max(scores['budget'] ?? 0.0, 0.60);
      }
    } else if (scores.containsKey('destination_info')) {
      scores['destination_info'] = min(scores['destination_info'] ?? 0.0, 0.45);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty || sorted.first.value < _fallbackThreshold) {
      return const _IntentClassification(
        intent: 'fallback',
        confidence: 0.0,
      );
    }

    return _IntentClassification(
      intent: sorted.first.key,
      confidence: sorted.first.value.clamp(0.0, 1.0),
    );
  }

  double _scoreIntent(String input, String intent) {
    final terms = _intentTerms[intent] ?? const [];
    final weight = _intentWeights[intent] ?? 1.0;

    if (terms.isEmpty) return 0.0;

    final inputTokens = _tokenize(input);
    final tokenSet = inputTokens.toSet();

    double rawScore = 0.0;

    for (final term in terms) {
      final normalizedTerm = _normalize(term);
      if (normalizedTerm.isEmpty) continue;

      final termTokens = _tokenize(normalizedTerm);

      if (termTokens.isEmpty) continue;

      if (_containsPhrase(input, normalizedTerm)) {
        rawScore +=
            termTokens.length > 1 ? 3.0 + termTokens.length * 0.25 : 1.2;
        continue;
      }

      final overlap = termTokens.where(tokenSet.contains).length;
      if (overlap > 0) {
        final overlapRatio = overlap / termTokens.length;
        if (termTokens.length == 1) {
          rawScore += 0.55;
        } else if (overlapRatio >= 0.6) {
          rawScore += 1.0 + overlapRatio;
        }
      }
    }

    final normalizer = max(3.0, sqrt(terms.length) * 2.3);
    return ((rawScore / normalizer) * weight).clamp(0.0, 1.0);
  }

  Map<String, dynamic> _extractSlots(String input) {
    final slots = <String, dynamic>{};

    final destination = _matchDestination(input);
    if (destination != null) {
      slots['destination'] = destination;
    }

    final season = _extractSeason(input);
    if (season != null) {
      slots['season'] = season;
    }

    final activity = _extractActivity(input);
    if (activity != null) {
      slots['activity'] = activity;
    }

    final budget = _extractBudget(input);
    if (budget != null) {
      slots['budget'] = budget;
    }

    if (_containsAny(input, const [
      'family',
      'kid',
      'kids',
      'child',
      'children',
      'parents',
      'elderly',
      'senior',
    ])) {
      slots['family'] = true;
    }

    if (_containsAny(input, const [
      'safe',
      'safety',
      'danger',
      'risk',
      'alone',
      'solo',
      'emergency',
      'landslide',
    ])) {
      slots['safety'] = true;
    }

    if (_containsAny(input, const [
      'bus',
      'jeep',
      'taxi',
      'road',
      'route',
      'reach',
      'transport',
    ])) {
      slots['transport'] = true;
    }

    return slots;
  }

  String _buildResponse({
    required String input,
    required String intent,
    required double confidence,
    required Map<String, dynamic> slots,
  }) {
    if (intent == 'fallback') {
      return _response('fallback');
    }

    final destination = slots['destination'] as Destination?;

    String response;

    if (destination != null) {
      response = _buildDestinationResponse(
        intent: intent,
        destination: destination,
        slots: slots,
      );
    } else {
      switch (intent) {
        case 'greeting':
          response = _randomResponse('greeting');
          break;
        case 'best_time_to_visit':
          response = _response('best_time_to_visit_generic');
          break;
        case 'transport':
          response = _response('transport_generic');
          break;
        case 'homestay':
          response = _response('homestay_generic');
          break;
        case 'food':
          response = _response('food_generic');
          break;
        case 'culture_etiquette':
          response = _response('culture_etiquette_generic');
          break;
        case 'safety':
          response = _response('safety_generic');
          break;
        case 'budget':
          response = _response('budget_generic');
          break;
        case 'trekking':
          response = _response('trekking_generic');
          break;
        case 'recommendation_help':
          response = _buildRecommendationResponse(slots);
          break;
        case 'nearby_places':
          response = _buildNearbyResponse(slots);
          break;
        case 'destination_info':
          response = _buildTopDestinationsResponse();
          break;
        case 'emergency_help':
          response = _response('emergency_help');
          break;
        case 'offline_help':
          response = _response('offline_help');
          break;
        case 'translation_help':
          response = _response('translation_help');
          break;
        case 'smalltalk':
          response = _response('smalltalk');
          break;
        default:
          response = _response('fallback');
      }
    }

    if (confidence >= _fallbackThreshold &&
        confidence < _mediumConfidenceThreshold &&
        destination == null &&
        intent != 'fallback') {
      response +=
          '\n\nI may not have understood the full context. You can also try asking about a specific destination, transport, homestay, safety, trekking, budget, or best season.';
    }

    return response;
  }

  String _buildDestinationResponse({
    required String intent,
    required Destination destination,
    required Map<String, dynamic> slots,
  }) {
    switch (intent) {
      case 'best_time_to_visit':
        return _destinationSeasonAnswer(destination, slots);
      case 'transport':
        return _destinationTransportAnswer(destination);
      case 'homestay':
        return _destinationHomestayAnswer(destination);
      case 'budget':
        return _destinationBudgetAnswer(destination);
      case 'culture_etiquette':
        return _destinationCultureAnswer(destination);
      case 'safety':
      case 'emergency_help':
        return _destinationSafetyAnswer(destination);
      case 'trekking':
        return _destinationTrekkingAnswer(destination);
      case 'nearby_places':
        return _buildNearbyForDestination(destination);
      case 'recommendation_help':
        return _buildRecommendationResponse({
          ...slots,
          'destination': destination,
        });
      default:
        return _destinationOverview(destination);
    }
  }

  String _destinationOverview(Destination destination) {
    final buffer = StringBuffer();

    buffer.writeln('📍 ${destination.name}');
    buffer.writeln();
    buffer.writeln('Location: ${_locationText(destination)}');
    buffer.writeln(destination.displayDescription);
    buffer.writeln();

    if (destination.activities.isNotEmpty) {
      buffer.writeln('🎯 Activities: ${destination.activities.join(", ")}');
    }

    if (destination.bestSeason.isNotEmpty) {
      buffer.writeln('🗓️ Best season: ${destination.bestSeason.join(", ")}');
    }

    buffer.writeln('💰 Budget level: ${destination.budgetLevel ?? "medium"}');
    buffer.writeln(
        '🚶 Accessibility: ${destination.accessibility ?? "moderate"}');

    if (destination.familyFriendly != null) {
      buffer.writeln(
        destination.familyFriendly == true
            ? '👨‍👩‍👧 Family friendly: yes'
            : '👨‍👩‍👧 Family friendly: limited',
      );
    }

    if (destination.adventureLevel != null) {
      buffer.writeln(
        '🥾 Adventure level: ${destination.adventureLevel}/5 — ${_adventureNote(destination.adventureLevel!)}',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'Ask me about the best season, transport, budget, safety, homestay, or nearby places for ${destination.name}.',
    );

    return buffer.toString().trim();
  }

  String _destinationSeasonAnswer(
    Destination destination,
    Map<String, dynamic> slots,
  ) {
    final askedSeason = slots['season'] as String?;
    final bestSeason = destination.bestSeason.isNotEmpty
        ? destination.bestSeason.join(', ')
        : 'spring and autumn';

    final buffer = StringBuffer();

    buffer.writeln('🗓️ Best time to visit ${destination.name}');
    buffer.writeln();
    buffer.writeln('Recommended season: $bestSeason.');

    if (askedSeason != null) {
      buffer.writeln(_seasonMatchNote(askedSeason, destination.bestSeason));
    }

    buffer.writeln();
    buffer.writeln(destination.shortDescription);

    if (destination.accessibility != null) {
      buffer.writeln();
      buffer.writeln('Accessibility: ${destination.accessibility}.');
    }

    return buffer.toString().trim();
  }

  String _destinationTransportAnswer(Destination destination) {
    return '🚗 Getting to ${destination.name}\n\n'
        'Location: ${_locationText(destination)}.\n\n'
        'From Pokhara, most rural destinations can be reached using local bus, shared jeep, private jeep, or a short trek depending on road access. '
        '${destination.accessibility != null ? "Accessibility is listed as ${destination.accessibility}. " : ""}'
        'Always confirm road conditions before leaving, especially during monsoon.\n\n'
        '${destination.shortDescription}';
  }

  String _destinationHomestayAnswer(Destination destination) {
    final hasHomestay = _destinationText(destination).contains('homestay');

    return '🏠 Homestay and accommodation near ${destination.name}\n\n'
        '${hasHomestay ? "${destination.name} is associated with homestay/community-style tourism. " : "Homestay availability may vary, so confirm before travelling. "}'
        'Budget level: ${destination.budgetLevel ?? "medium"}.\n\n'
        '${destination.familyFriendly == true ? "This destination is suitable for families. " : ""}'
        'During peak seasons, book rooms early and ask whether meals, hot water, and transport pickup are included.';
  }

  String _destinationBudgetAnswer(Destination destination) {
    return '💰 Budget for ${destination.name}\n\n'
        'Budget level: ${destination.budgetLevel ?? "medium"}.\n'
        '${_budgetDetail(destination.budgetLevel)}\n\n'
        'Carry Nepali rupees in cash because rural villages may not accept cards or digital payments.';
  }

  String _destinationCultureAnswer(Destination destination) {
    return '🙏 Culture and etiquette at ${destination.name}\n\n'
        '${destination.displayDescription}\n\n'
        '${destination.cultureLevel != null ? "Culture richness: ${destination.cultureLevel}/5.\n\n" : ""}'
        'General etiquette: greet with Namaste, ask before taking photos, dress modestly around religious sites, remove shoes before entering homes or temples, and respect local customs.';
  }

  String _destinationSafetyAnswer(Destination destination) {
    return '🛡️ Safety advice for ${destination.name}\n\n'
        '${destination.accessibility != null ? "Accessibility: ${destination.accessibility}.\n" : ""}'
        '${destination.adventureLevel != null ? "Adventure level: ${destination.adventureLevel}/5 — ${_adventureNote(destination.adventureLevel!)}.\n" : ""}'
        '${destination.familyFriendly == true ? "This destination is generally suitable for families.\n" : ""}'
        '\nAvoid unfamiliar routes alone, check weather before travelling, inform your host about your route, and carry basic first aid.\n\n'
        'Emergency numbers: Police 100, Ambulance 102, Tourist Police 01-4247041.';
  }

  String _destinationTrekkingAnswer(Destination destination) {
    final activities =
        destination.activities.map((e) => e.toLowerCase()).toList();
    final hasTrekking = activities.any(
      (activity) => activity.contains('trek') || activity.contains('hike'),
    );

    return '🥾 Trekking information for ${destination.name}\n\n'
        '${hasTrekking ? "Trekking or hiking is listed as an activity here. " : "This may not be a primary trekking destination, but it can still be part of a rural travel route. "}'
        'Adventure level: ${destination.adventureLevel ?? "moderate"}/5.\n'
        'Best season: ${destination.bestSeason.isNotEmpty ? destination.bestSeason.join(", ") : "spring and autumn"}.\n\n'
        '${destination.shortDescription}\n\n'
        'For trekking, carry water, rain protection, warm layers, offline maps, and inform someone about your route.';
  }

  String _buildRecommendationResponse(Map<String, dynamic> slots) {
    final activity = slots['activity'] as String?;
    final budget = slots['budget'] as String?;
    final family = slots['family'] as bool?;

    var filtered = destinations.toList();

    if (activity != null) {
      filtered = filtered.where((destination) {
        final text = _destinationText(destination);
        return text.contains(activity);
      }).toList();
    }

    if (budget != null) {
      filtered = filtered.where((destination) {
        final level = destination.budgetLevel?.toLowerCase() ?? '';
        if (budget == 'budget') return level == 'budget';
        if (budget == 'premium') return level == 'premium';
        if (budget == 'medium') return level == 'medium';
        return true;
      }).toList();
    }

    if (family == true) {
      filtered = filtered.where((d) => d.familyFriendly == true).toList();
    }

    if (filtered.isEmpty) {
      return _response('recommendation_help');
    }

    filtered.sort((a, b) {
      final aScore = _simpleDestinationScore(a, activity, budget, family);
      final bScore = _simpleDestinationScore(b, activity, budget, family);
      return bScore.compareTo(aScore);
    });

    final top = filtered.take(3).toList();

    final buffer = StringBuffer();

    buffer.writeln('Here are some suitable destinations:');
    buffer.writeln();

    for (final destination in top) {
      buffer.writeln('📍 ${destination.name} — ${_locationText(destination)}');
      buffer.writeln(destination.shortDescription);
      buffer.writeln(
        'Budget: ${destination.budgetLevel ?? "medium"} | Season: ${destination.bestSeason.isNotEmpty ? destination.bestSeason.first : "spring/autumn"}',
      );
      buffer.writeln();
    }

    buffer.writeln(
      'For a ranked list with scores, open the Recommend tab and set your activity, budget, season, vibe, family preference, and adventure level.',
    );

    return buffer.toString().trim();
  }

  String _buildNearbyResponse(Map<String, dynamic> slots) {
    final destination = slots['destination'] as Destination?;

    if (destination != null) {
      return _buildNearbyForDestination(destination);
    }

    return 'To find nearby places, mention a specific destination. For example:\n\n'
        '• What places are near Ghandruk?\n'
        '• What is close to Sikles?\n'
        '• Nearby places around Begnas Lake?\n\n'
        'You can also use the Map tab to explore destinations visually.';
  }

  String _buildNearbyForDestination(Destination origin) {
    if (origin.latitude == null || origin.longitude == null) {
      return 'I do not have enough location data for ${origin.name} to calculate nearby places. Try using the Map tab for visual exploration.';
    }

    final nearby = destinations
        .where(
          (destination) =>
              destination.id != origin.id &&
              destination.latitude != null &&
              destination.longitude != null,
        )
        .map(
          (destination) => _NearbyDestination(
            destination: destination,
            distanceKm: haversineKm(
              origin.latitude!,
              origin.longitude!,
              destination.latitude!,
              destination.longitude!,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final top = nearby.take(4).toList();

    if (top.isEmpty) {
      return 'No nearby destinations were found in the local database.';
    }

    final buffer = StringBuffer();

    buffer.writeln('📍 Places near ${origin.name}:');
    buffer.writeln();

    for (final item in top) {
      buffer.writeln(
        '• ${item.destination.name} — ${item.distanceKm.toStringAsFixed(1)} km away',
      );
      buffer.writeln('  ${item.destination.shortDescription}');
    }

    buffer.writeln();
    buffer.writeln('Use the Map tab to compare these locations visually.');

    return buffer.toString().trim();
  }

  String _buildTopDestinationsResponse() {
    final topDestinations = destinations.take(5).toList();

    if (topDestinations.isEmpty) {
      return 'I could not find destination data right now. Please check the Home or Recommend tab.';
    }

    final buffer = StringBuffer();

    buffer.writeln('🗺️ Some destinations you can explore:');
    buffer.writeln();

    for (final destination in topDestinations) {
      buffer
          .writeln('📍 ${destination.name} — ${destination.shortDescription}');
    }

    buffer.writeln();
    buffer.writeln(
      'Ask me about any destination by name, or use the Recommend tab for personalised suggestions.',
    );

    return buffer.toString().trim();
  }

  Map<String, Destination> _buildDestinationAliasMap() {
    final aliases = <String, Destination>{};

    final tokenCounts = <String, int>{};

    for (final destination in destinations) {
      for (final token in _tokenize(destination.name)) {
        if (!_isGenericDestinationToken(token)) {
          tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
        }
      }
    }

    for (final destination in destinations) {
      final normalizedName = _normalize(destination.name);
      if (normalizedName.isNotEmpty) {
        aliases[normalizedName] = destination;
      }

      for (final token in _tokenize(destination.name)) {
        if (!_isGenericDestinationToken(token) && tokenCounts[token] == 1) {
          aliases[token] = destination;
        }
      }
    }

    final rawAliases = Map<String, dynamic>.from(
      (_knowledgeBase['destination_aliases'] as Map?) ?? const {},
    );

    for (final entry in rawAliases.entries) {
      final destination = _findDestinationByName(entry.key);
      if (destination == null) continue;

      for (final alias in _readStringList(entry.value)) {
        final normalizedAlias = _normalize(alias);
        if (normalizedAlias.isNotEmpty) {
          aliases[normalizedAlias] = destination;
        }
      }
    }

    return aliases;
  }

  Destination? _matchDestination(String input) {
    final aliases = _aliasToDestination.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final alias in aliases) {
      if (alias.length <= 2) continue;

      if (_containsPhrase(input, alias)) {
        return _aliasToDestination[alias];
      }
    }

    return null;
  }

  Destination? _findDestinationByName(String name) {
    final normalized = _normalize(name);

    for (final destination in destinations) {
      if (_normalize(destination.name) == normalized) {
        return destination;
      }
    }

    for (final destination in destinations) {
      if (_normalize(destination.name).contains(normalized)) {
        return destination;
      }
    }

    return null;
  }

  String? _extractSeason(String input) {
    if (_containsAny(input, const ['spring', 'march', 'april', 'may'])) {
      return 'spring';
    }

    if (_containsAny(
        input, const ['autumn', 'fall', 'september', 'october', 'november'])) {
      return 'autumn';
    }

    if (_containsAny(
        input, const ['monsoon', 'rainy', 'rain', 'june', 'july', 'august'])) {
      return 'monsoon';
    }

    if (_containsAny(
        input, const ['winter', 'december', 'january', 'february', 'cold'])) {
      return 'winter';
    }

    if (_containsAny(input, const ['summer', 'hot'])) {
      return 'summer';
    }

    return null;
  }

  String? _extractActivity(String input) {
    if (_containsAny(
        input, const ['trek', 'trekking', 'hike', 'hiking', 'trail'])) {
      return 'trekking';
    }

    if (_containsAny(input,
        const ['culture', 'cultural', 'temple', 'monastery', 'tradition'])) {
      return 'culture';
    }

    if (_containsAny(
        input, const ['relax', 'relaxation', 'peace', 'peaceful', 'quiet'])) {
      return 'relaxation';
    }

    if (_containsAny(
        input, const ['photo', 'photography', 'view', 'sunrise', 'scenic'])) {
      return 'photography';
    }

    if (_containsAny(input, const ['boat', 'boating', 'lake'])) {
      return 'boating';
    }

    if (_containsAny(input, const ['wildlife', 'bird', 'forest'])) {
      return 'wildlife';
    }

    return null;
  }

  String? _extractBudget(String input) {
    if (_containsAny(input, const [
      'budget',
      'cheap',
      'low cost',
      'affordable',
      'low budget',
      'save money',
    ])) {
      return 'budget';
    }

    if (_containsAny(input, const [
      'premium',
      'luxury',
      'comfortable',
      'high budget',
      'expensive',
    ])) {
      return 'premium';
    }

    if (_containsAny(input, const [
      'medium',
      'moderate',
      'mid range',
      'mid-range',
    ])) {
      return 'medium';
    }

    return null;
  }

  bool _isEmergencyQuestion(String input) {
    return _containsAny(input, const [
      'emergency',
      'sos',
      'rescue',
      'accident',
      'injured',
      'badly hurt',
      'lost in forest',
      'missing person',
      'need ambulance',
      'need police',
      'call police',
      'call ambulance',
    ]);
  }

  bool _isSafetyQuestion(String input) {
    return _containsAny(input, const [
      'is it safe',
      'safe',
      'safe to',
      'safety',
      'danger',
      'dangerous',
      'risk',
      'alone',
      'solo',
      'female traveller',
      'woman traveller',
      'landslide',
      'altitude sickness',
    ]);
  }

  bool _isRecommendationQuestion(String input) {
    return _containsAny(input, const [
      'recommend',
      'suggest',
      'where should i go',
      'which place',
      'best place',
      'best destination',
      'peaceful village',
      'family destination',
      'budget destination',
    ]);
  }

  bool _containsAny(String input, List<String> terms) {
    for (final term in terms) {
      if (_containsPhrase(input, _normalize(term))) {
        return true;
      }
    }

    return false;
  }

  bool _containsPhrase(String input, String phrase) {
    if (phrase.isEmpty) return false;

    if (phrase.contains(' ')) {
      return input.contains(phrase);
    }

    final pattern = RegExp(
      '(^|\\s)${RegExp.escape(phrase)}(\\s|\$)',
      caseSensitive: false,
    );

    return pattern.hasMatch(input);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _tokenize(String value) {
    return _normalize(value)
        .split(' ')
        .map(_stemToken)
        .where((token) => token.length >= 2)
        .toList();
  }

  String _stemToken(String token) {
    if (token.length > 5 && token.endsWith('ing')) {
      return token.substring(0, token.length - 3);
    }

    if (token.length > 4 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }

    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }

    return token;
  }

  bool _isGenericDestinationToken(String token) {
    return const {
      'lake',
      'hill',
      'village',
      'temple',
      'view',
      'point',
      'rural',
      'tourism',
      'pokhara',
      'nepal',
      'trail',
      'camp',
      'base',
      'area',
    }.contains(token);
  }

  String _locationText(Destination destination) {
    if (destination.locationText.isNotEmpty) {
      return destination.locationText;
    }

    return [
      destination.district,
      destination.province,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
  }

  String _destinationText(Destination destination) {
    return _normalize(
      [
        destination.name,
        destination.province,
        destination.district,
        destination.municipality,
        destination.category.join(' '),
        destination.activities.join(' '),
        destination.bestSeason.join(' '),
        destination.budgetLevel,
        destination.accessibility,
        destination.shortDescription,
        destination.fullDescription,
        destination.tags.join(' '),
      ].whereType<String>().join(' '),
    );
  }

  double _simpleDestinationScore(
    Destination destination,
    String? activity,
    String? budget,
    bool? family,
  ) {
    double score = 0.0;
    final text = _destinationText(destination);

    if (activity != null && text.contains(activity)) {
      score += 2.0;
    }

    if (budget != null && destination.budgetLevel == budget) {
      score += 1.2;
    }

    if (family == true && destination.familyFriendly == true) {
      score += 1.0;
    }

    score += (destination.adventureLevel ?? 0) * 0.05;
    score += (destination.cultureLevel ?? 0) * 0.04;
    score += (destination.natureLevel ?? 0) * 0.04;

    return score;
  }

  String _randomResponse(String key) {
    final value = _responses[key];

    if (value is List && value.isNotEmpty) {
      return value[Random().nextInt(value.length)].toString();
    }

    if (value is String) {
      return value;
    }

    return _response('fallback');
  }

  String _response(String key) {
    final value = _responses[key];

    if (value is String) {
      return value;
    }

    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }

    return 'I’m not fully sure about that specific question. Please ask about destinations, best season, transport, homestays, safety, food, culture, budget, trekking, or recommendations.';
  }

  String _seasonMatchNote(String askedSeason, List<String> bestSeasons) {
    final normalizedBest =
        bestSeasons.map((season) => season.toLowerCase()).toList();

    if (normalizedBest.contains(askedSeason.toLowerCase())) {
      return '✅ $askedSeason is listed as one of the best seasons for this destination.';
    }

    if (bestSeasons.isEmpty) {
      return 'Spring and autumn are generally safer choices for rural travel.';
    }

    return '⚠️ $askedSeason may not be the peak season here. Consider ${bestSeasons.first} for a better experience.';
  }

  String _budgetDetail(String? level) {
    switch (level?.toLowerCase()) {
      case 'budget':
        return 'Expected cost: around NRP 2,000–4,000 per day with simple homestay and meals.';
      case 'medium':
        return 'Expected cost: around NRP 4,000–8,000 per day with comfortable stay, meals, and local transport.';
      case 'premium':
        return 'Expected cost: NRP 8,000+ per day with guided service, private transport, or premium lodging.';
      default:
        return 'Costs vary by season, transport, and accommodation. Confirm with local hosts before travelling.';
    }
  }

  String _adventureNote(int level) {
    if (level <= 1) return 'very easy, suitable for most visitors';
    if (level == 2) return 'easy to moderate, good for beginners';
    if (level == 3) return 'moderate, basic fitness recommended';
    if (level == 4) return 'challenging, guide recommended';
    return 'very challenging, experienced trekkers only';
  }

  List<String> _readStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return value
        .toString()
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _IntentClassification {
  final String intent;
  final double confidence;

  const _IntentClassification({
    required this.intent,
    required this.confidence,
  });
}

class _NearbyDestination {
  final Destination destination;
  final double distanceKm;

  const _NearbyDestination({
    required this.destination,
    required this.distanceKm,
  });
}
