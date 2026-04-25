import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../core/utils/haversine.dart';
import '../models/chat_message.dart';
import '../models/destination.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatbotService
//
// Offline-first intent-based chatbot for Nepal Rural Tourism.
//
// Architecture:
//   1. Intent classification  — weighted keyword matching (TF-IDF style)
//   2. Slot extraction        — destination name, season, activity, budget
//   3. Response building      — pulls real data from destinations list
//   4. Nearby resolver        — uses haversine.dart for proximity
//
// No internet required. No API keys. No paid packages.
// ─────────────────────────────────────────────────────────────────────────────

class ChatbotService {
  final List<Destination> destinations;

  late Map<String, dynamic> _kb;           // knowledge base JSON
  late Map<String, List<String>> _intentKeywords;
  late Map<String, double>      _intentWeights;
  late List<String>             _destNames; // lowercase for matching

  bool _ready = false;

  ChatbotService({required this.destinations});

  // ── init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;
    final raw = await rootBundle.loadString('assets/data/chatbot_knowledge_base.json');
    _kb = jsonDecode(raw) as Map<String, dynamic>;

    final intentsMap = _kb['intents'] as Map<String, dynamic>;
    _intentKeywords = {};
    _intentWeights  = {};
    for (final entry in intentsMap.entries) {
      final data = entry.value as Map<String, dynamic>;
      _intentKeywords[entry.key] = List<String>.from(data['keywords'] as List);
      _intentWeights[entry.key]  = (data['weight'] as num).toDouble();
    }

    _destNames = destinations.map((d) => d.name.toLowerCase()).toList();
    _ready = true;
  }

  // ── public API ────────────────────────────────────────────────────────────

  /// Main entry point: classify intent, extract slots, build response.
  ChatMessage respond(String userText) {
    assert(_ready, 'Call init() before respond()');

    final input     = userText.toLowerCase().trim();
    final intent    = _classifyIntent(input);
    final slots     = _extractSlots(input);
    final response  = _buildResponse(intent, slots, input);

    return ChatMessage.fromBot(
      response,
      detectedIntent: intent,
      confidence: _scoreForIntent(input, intent),
    );
  }

  /// Initial greeting message from bot
  ChatMessage greetingMessage() {
    final responses = _kb['responses']['greeting'] as List;
    return ChatMessage.fromBot(responses[0] as String, detectedIntent: 'greeting', confidence: 1.0);
  }

  /// Quick suggestion chips shown at the start and after certain intents
  List<QuickSuggestion> initialSuggestions() => [
    const QuickSuggestion(label: '🗓️ Best time to visit', message: 'When is the best time to visit?'),
    const QuickSuggestion(label: '🥾 Trekking routes',    message: 'What trekking routes are available?'),
    const QuickSuggestion(label: '🏠 Homestays',          message: 'Tell me about homestay accommodation'),
    const QuickSuggestion(label: '💰 Budget tips',        message: 'What is the daily budget needed?'),
    const QuickSuggestion(label: '🙏 Culture tips',       message: 'What cultural etiquette should I know?'),
    const QuickSuggestion(label: '🚗 Getting there',      message: 'How do I get to the villages from Pokhara?'),
  ];

  List<QuickSuggestion> suggestionsForIntent(String intent) {
    switch (intent) {
      case 'trekking':
        return [
          const QuickSuggestion(label: 'Permits needed?',   message: 'What permits do I need for trekking?'),
          const QuickSuggestion(label: 'Difficulty levels?', message: 'What are easy trekking routes for beginners?'),
        ];
      case 'budget':
        return [
          const QuickSuggestion(label: 'Budget homestay?', message: 'Which destinations have budget homestays?'),
          const QuickSuggestion(label: 'Entry fees?',       message: 'Are there any entry fees?'),
        ];
      case 'best_time_to_visit':
        return [
          const QuickSuggestion(label: 'Spring visit?', message: 'What is spring trekking like?'),
          const QuickSuggestion(label: 'Monsoon okay?', message: 'Can I visit during monsoon?'),
        ];
      default:
        return [
          const QuickSuggestion(label: '📍 Nearby places',     message: 'What places are nearby?'),
          const QuickSuggestion(label: '🗺️ More destinations', message: 'Show me recommended destinations'),
        ];
    }
  }

  // ── intent classification ─────────────────────────────────────────────────

  String _classifyIntent(String input) {
    final scores = <String, double>{};

    for (final intent in _intentKeywords.keys) {
      if (intent == 'fallback') continue;
      scores[intent] = _scoreForIntent(input, intent);
    }

    // Check for emergency intent first (highest priority)
    if ((scores['emergency_help'] ?? 0) > 0.3) return 'emergency_help';

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty || sorted.first.value < 0.08) return 'fallback';
    return sorted.first.key;
  }

  double _scoreForIntent(String input, String intent) {
    final keywords = _intentKeywords[intent] ?? [];
    final weight   = _intentWeights[intent]  ?? 1.0;

    if (keywords.isEmpty) return 0.0;

    double score = 0.0;
    for (final kw in keywords) {
      if (input.contains(kw)) {
        // Longer keywords score higher (TF-IDF style term weighting)
        score += (kw.split(' ').length > 1) ? 2.0 : 1.0;
      }
    }
    // Normalise by keyword count then apply intent weight
    return (score / keywords.length) * weight;
  }

  // ── slot extraction ───────────────────────────────────────────────────────

  Map<String, dynamic> _extractSlots(String input) {
    final slots = <String, dynamic>{};

    // Destination name slot
    Destination? matched;
    double bestScore = 0;
    for (int i = 0; i < _destNames.length; i++) {
      final name  = _destNames[i];
      final words = name.split(' ');
      double score = 0;
      for (final w in words) {
        if (input.contains(w)) score += 1;
      }
      final norm = score / words.length;
      if (norm > bestScore && norm > 0.5) {
        bestScore = norm;
        matched   = destinations[i];
      }
    }
    if (matched != null) slots['destination'] = matched;

    // Season slot
    for (final s in ['spring', 'autumn', 'summer', 'winter', 'monsoon']) {
      if (input.contains(s)) { slots['season'] = s; break; }
    }

    // Activity slot
    for (final a in ['trekking', 'hiking', 'culture', 'photography', 'relaxation', 'wildlife', 'boating']) {
      if (input.contains(a)) { slots['activity'] = a; break; }
    }

    // Budget slot
    for (final b in ['budget', 'cheap', 'affordable', 'premium', 'expensive', 'medium']) {
      if (input.contains(b)) { slots['budget'] = b; break; }
    }

    // Family slot
    if (input.contains('family') || input.contains('kids') || input.contains('children')) {
      slots['family'] = true;
    }

    return slots;
  }

  // ── response builder ──────────────────────────────────────────────────────

  String _buildResponse(String intent, Map<String, dynamic> slots, String input) {
    final dest = slots['destination'] as Destination?;

    // If a specific destination was mentioned, enrich with real data
    if (dest != null) {
      return _buildDestinationResponse(intent, dest, slots);
    }

    // Generic intent responses from knowledge base
    final responses = _kb['responses'] as Map<String, dynamic>;

    switch (intent) {
      case 'greeting':
        final list = responses['greeting'] as List;
        return list[Random().nextInt(list.length)] as String;

      case 'best_time_to_visit':
        return responses['best_time_to_visit_generic'] as String;

      case 'transport':
        return responses['transport_generic'] as String;

      case 'homestay':
        return responses['homestay_generic'] as String;

      case 'food':
        return responses['food_generic'] as String;

      case 'culture_etiquette':
        return responses['culture_etiquette_generic'] as String;

      case 'safety':
        return responses['safety_generic'] as String;

      case 'budget':
        return responses['budget_generic'] as String;

      case 'trekking':
        return responses['trekking_generic'] as String;

      case 'recommendation_help':
        return _buildRecommendationResponse(slots);

      case 'nearby_places':
        return _buildNearbyResponse(slots);

      case 'destination_info':
        return _buildTopDestinationsResponse();

      case 'emergency_help':
        return responses['emergency_help'] as String;

      case 'offline_help':
        return responses['offline_help'] as String;

      case 'smalltalk':
        return responses['smalltalk'] as String;

      default:
        return responses['fallback'] as String;
    }
  }

  String _buildDestinationResponse(
    String intent,
    Destination dest,
    Map<String, dynamic> slots,
  ) {
    final name   = dest.name;
    final loc    = dest.locationText.isNotEmpty ? dest.locationText : dest.province;
    final season = slots['season'] as String?;

    switch (intent) {
      case 'best_time_to_visit':
        final seasons = dest.bestSeason.isNotEmpty
            ? dest.bestSeason.join(' and ')
            : 'spring and autumn';
        return '🗓️ Best time to visit $name:\n\nThe ideal seasons are $seasons. '
            '${season != null ? _seasonMatchNote(season, dest.bestSeason) : ''}\n\n'
            '${dest.shortDescription}\n\n'
            'Accessibility: ${dest.accessibility ?? "moderate"}. '
            '${dest.adventureLevel != null ? "Adventure level: ${dest.adventureLevel}/5." : ""}';

      case 'transport':
        return '🚗 Getting to $name ($loc):\n\n'
            'Take a jeep or local bus from Pokhara towards ${dest.district ?? dest.province} district. '
            'The destination is ${dest.accessibility == "easy" ? "easily accessible" : dest.accessibility ?? "moderately accessible"} '
            'and can be reached in 1–3 hours from Pokhara city.\n\n'
            '${dest.shortDescription}';

      case 'homestay':
        final hasHomestay = dest.tags.any((t) => t.toLowerCase().contains('homestay'));
        return '🏠 Accommodation at $name:\n\n'
            '${hasHomestay ? "$name is known for its traditional homestays. " : ""}'
            'Budget level: ${dest.budgetLevel ?? "medium"}. '
            '${dest.familyFriendly == true ? "This destination is family friendly." : ""}\n\n'
            '${dest.shortDescription}\n\n'
            'Book in advance during peak season (Oct–Nov, Mar–Apr).';

      case 'budget':
        return '💰 Budget for $name:\n\n'
            'Budget level: ${dest.budgetLevel ?? "medium"}.\n'
            '${_budgetDetail(dest.budgetLevel)}\n\n'
            '${dest.familyFriendly == true ? "✅ Family friendly destination." : ""}';

      case 'culture_etiquette':
        final cultureLevel = dest.cultureLevel;
        return '🙏 Culture at $name:\n\n'
            '${cultureLevel != null ? "Culture richness: $cultureLevel/5." : ""} '
            '${dest.fullDescription.isNotEmpty ? dest.fullDescription : dest.shortDescription}\n\n'
            'General tips: dress modestly, remove shoes at temples, greet with Namaste.';

      case 'safety':
        return '🛡️ Safety at $name:\n\n'
            '${dest.accessibility != null ? "Accessibility: ${dest.accessibility}." : ""} '
            '${dest.adventureLevel != null ? "Adventure level: ${dest.adventureLevel}/5 — ${_adventureNote(dest.adventureLevel!)}." : ""}\n\n'
            '${dest.familyFriendly == true ? "✅ Suitable for families and beginners." : ""}\n\n'
            'Emergency: Police 100 | Ambulance 102 | Tourist Police 01-4247041.';

      case 'trekking':
        final hasTrekking = dest.activities.any((a) => a.contains('trek') || a.contains('hike'));
        return '🥾 Trekking at $name:\n\n'
            '${hasTrekking ? "Trekking is a primary activity at $name. " : ""}'
            'Adventure level: ${dest.adventureLevel ?? "moderate"}/5.\n'
            'Best season: ${dest.bestSeason.isNotEmpty ? dest.bestSeason.join(", ") : "spring and autumn"}.\n\n'
            '${dest.fullDescription.isNotEmpty ? dest.fullDescription : dest.shortDescription}';

      case 'nearby_places':
        return _buildNearbyForDestination(dest);

      default:
        // destination_info or anything else with a named destination
        return '📍 $name — $loc\n\n'
            '${dest.fullDescription.isNotEmpty ? dest.fullDescription : dest.shortDescription}\n\n'
            '🏷️ Categories: ${dest.category.join(", ")}\n'
            '🎯 Activities: ${dest.activities.isNotEmpty ? dest.activities.join(", ") : "various"}\n'
            '🗓️ Best season: ${dest.bestSeason.isNotEmpty ? dest.bestSeason.join(", ") : "all year"}\n'
            '💰 Budget: ${dest.budgetLevel ?? "medium"}\n'
            '🧗 Adventure level: ${dest.adventureLevel ?? "?"}/5\n'
            '${dest.familyFriendly == true ? "👨‍👩‍👧 Family friendly\n" : ""}'
            '${dest.tags.isNotEmpty ? "🏷️ Tags: ${dest.tags.join(", ")}" : ""}';
    }
  }

  String _buildRecommendationResponse(Map<String, dynamic> slots) {
    final activity = slots['activity'] as String?;
    final budget   = slots['budget']   as String?;
    final family   = slots['family']   as bool?;

    // Filter destinations based on slots
    var filtered = destinations.toList();
    if (activity != null) {
      filtered = filtered
          .where((d) => d.activities.any((a) => a.toLowerCase().contains(activity)))
          .toList();
    }
    if (budget != null && (budget == 'budget' || budget == 'cheap' || budget == 'affordable')) {
      filtered = filtered.where((d) => d.budgetLevel == 'budget').toList();
    }
    if (family == true) {
      filtered = filtered.where((d) => d.familyFriendly == true).toList();
    }

    // Take top 3
    filtered = filtered.take(3).toList();

    if (filtered.isEmpty) {
      return '🗺️ I recommend opening the Recommend tab (the slider icon) for personalised suggestions.\n\n'
          'Some popular starting points:\n'
          '• Ghandruk — cultural trekking village\n'
          '• Dhampus — easy day hike, great views\n'
          '• Sarangkot — sunrise views, accessible\n\n'
          'Set your activity, budget, and season in the Recommend tab for a full personalised list.';
    }

    final buf = StringBuffer();
    buf.writeln('Here are some ${activity != null ? "$activity " : ""}destinations${family == true ? " suitable for families" : ""}:\n');
    for (final d in filtered) {
      buf.writeln('📍 ${d.name} (${d.district ?? d.province})');
      buf.writeln('   ${d.shortDescription}');
      buf.writeln('   Budget: ${d.budgetLevel ?? "medium"} | Season: ${d.bestSeason.isNotEmpty ? d.bestSeason.first : "spring/autumn"}');
      buf.writeln();
    }
    buf.writeln('👉 Use the Recommend tab for a full personalised list with scores and explanations.');
    return buf.toString().trim();
  }

  String _buildNearbyResponse(Map<String, dynamic> slots) {
    final dest = slots['destination'] as Destination?;
    if (dest != null) return _buildNearbyForDestination(dest);

    return 'To find nearby places, mention a specific destination. For example: '
        '"What places are near Ghandruk?" or "What is close to Sikles?"\n\n'
        'Or use the Map tab to explore destinations by location.';
  }

  String _buildNearbyForDestination(Destination origin) {
    if (origin.latitude == null || origin.longitude == null) {
      return 'I don\'t have location data for ${origin.name} to find nearby places. '
          'Try the Map tab to explore visually.';
    }

    final nearby = destinations
        .where((d) => d.id != origin.id && d.latitude != null && d.longitude != null)
        .map((d) => (
              dest: d,
              dist: haversineKm(
                origin.latitude!, origin.longitude!,
                d.latitude!,      d.longitude!,
              ),
            ))
        .toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));

    final top = nearby.take(4).toList();
    if (top.isEmpty) return 'No nearby places found in the database.';

    final buf = StringBuffer();
    buf.writeln('📍 Places near ${origin.name}:\n');
    for (final item in top) {
      buf.writeln('• ${item.dest.name} — ${item.dist.toStringAsFixed(1)} km away');
      buf.writeln('  ${item.dest.shortDescription}');
    }
    buf.writeln('\nUse the Map tab to see all destinations visually.');
    return buf.toString().trim();
  }

  String _buildTopDestinationsResponse() {
    final top = destinations.take(5).toList();
    final buf = StringBuffer('🗺️ Popular destinations in Gandaki:\n\n');
    for (final d in top) {
      buf.writeln('📍 ${d.name} — ${d.shortDescription}');
    }
    buf.writeln('\nAsk me about any destination by name for full details, or use the Recommend tab for personalised suggestions.');
    return buf.toString().trim();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _seasonMatchNote(String asked, List<String> best) {
    if (best.contains(asked)) {
      return '✅ $asked is one of the ideal seasons for this destination.';
    }
    return '⚠️ $asked is not the peak season here — consider visiting in ${best.isNotEmpty ? best.first : "spring or autumn"} for the best experience.';
  }

  String _budgetDetail(String? level) {
    switch (level) {
      case 'budget':  return 'Expect to spend NRP 2,000–4,000 per day including homestay and meals.';
      case 'medium':  return 'Expect to spend NRP 4,000–7,000 per day including guesthouse and meals.';
      case 'premium': return 'Expect to spend NRP 7,000+ per day with guided service and comfortable lodges.';
      default:        return 'Budget varies — check with local agencies in Pokhara for current rates.';
    }
  }

  String _adventureNote(int level) {
    switch (level) {
      case 1: return 'very easy, suitable for all ages';
      case 2: return 'light, good for beginners';
      case 3: return 'moderate, some fitness required';
      case 4: return 'challenging, experienced hikers recommended';
      case 5: return 'extreme, expert level only';
      default: return 'moderate difficulty';
    }
  }
}