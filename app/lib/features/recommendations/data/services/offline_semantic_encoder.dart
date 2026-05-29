import 'dart:math';

import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';

abstract final class OfflineSemanticEncoder {
  static const String modelName = 'gandaki-offline-semantic-v1';
  static const int dimension = 96;
  static const int _conceptDimensions = 28;

  static const _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'by',
    'for',
    'from',
    'in',
    'into',
    'is',
    'it',
    'near',
    'of',
    'on',
    'or',
    'the',
    'to',
    'with',
  };

  static const List<List<String>> _conceptLexicon = [
    ['trekking', 'hiking', 'trail', 'ridge', 'pass', 'base camp', 'mountain'],
    ['adventure', 'climbing', 'cave', 'high altitude', 'expedition', 'thrill'],
    ['culture', 'cultural', 'heritage', 'museum', 'traditional', 'history'],
    ['village', 'homestay', 'community', 'local food', 'terrace', 'rural'],
    ['pilgrimage', 'temple', 'spiritual', 'dham', 'gumba', 'monastery'],
    ['nature', 'forest', 'river', 'valley', 'landscape', 'green hills'],
    ['wildlife', 'bird', 'birding', 'conservation', 'wetland', 'jungle'],
    ['lake', 'boating', 'waterside', 'pond', 'waterfall', 'hot spring'],
    ['scenic', 'viewpoint', 'panorama', 'sunrise', 'photography', 'view'],
    ['family', 'safe', 'easy', 'picnic', 'children', 'accessible'],
    ['peaceful', 'quiet', 'relax', 'retreat', 'calm', 'slow travel'],
    ['budget', 'low cost', 'basic rooms', 'affordable', 'homestay'],
    ['medium', 'guesthouse', 'lodge', 'private rooms', 'comfort'],
    ['premium', 'hotel', 'resort', 'luxury', 'comfort'],
    ['spring', 'rhododendron', 'flowers', 'clear weather'],
    ['autumn', 'festival', 'clear sky', 'mountain view'],
    ['winter', 'cool weather', 'clear view', 'snow'],
    ['monsoon', 'summer', 'green hills', 'rainy season'],
    ['food', 'market', 'bazaar', 'apple', 'local meals'],
    ['gorkha', 'durbar', 'palace', 'fort', 'historic'],
    ['mustang', 'manang', 'himalaya', 'trans himalaya', 'dry valley'],
    ['pokhara', 'kaski', 'phewa', 'begnas', 'sarangkot'],
    ['nawalpur', 'lowland', 'plain', 'tharu', 'community forest'],
    ['myagdi', 'baglung', 'parbat', 'hot spring', 'kalika'],
    ['lamjung', 'marsyangdi', 'gurung', 'ghalegaun'],
    ['tanahun', 'bandipur', 'cave', 'seti', 'damauli'],
    ['syangja', 'aandhikhola', 'hill', 'orange', 'palace'],
    ['accessibility', 'easy', 'moderate', 'difficult', 'road', 'walk'],
  ];

  static List<double> encodeDestination(Destination destination) {
    final vector = List<double>.filled(dimension, 0.0);

    _addText(vector, destination.name, 3.2);
    _addText(vector, destination.district ?? '', 1.6);
    _addText(vector, destination.municipality ?? '', 1.1);
    _addText(vector, destination.category.join(' '), 4.2);
    _addText(vector, destination.activities.join(' '), 4.0);
    _addText(vector, destination.tags.join(' '), 2.8);
    _addText(vector, destination.shortDescription, 1.8);
    _addText(vector, destination.fullDescription, 1.2);
    _addText(vector, destination.priceTier, 1.2);
    _addText(vector, destination.accessibility ?? '', 1.0);
    _addText(vector, destination.bestSeason.join(' '), 1.4);

    if (destination.familyFriendly == true) {
      _addText(vector, 'family safe easy accessible', 2.0);
    }

    _addLevel(vector, 0, destination.adventureLevel, 0.28);
    _addLevel(vector, 2, destination.cultureLevel, 0.28);
    _addLevel(vector, 5, destination.natureLevel, 0.28);

    return _l2Normalize(vector);
  }

  static List<double> encodePreferences(
    UserPreferences prefs, {
    bool? familyFriendly,
    int? adventureLevel,
  }) {
    final vector = List<double>.filled(dimension, 0.0);

    _addText(vector, prefs.activity, 5.0);
    _addText(vector, _expandedActivity(prefs.activity), 3.5);
    _addText(vector, prefs.vibe, 4.0);
    _addText(vector, _expandedVibe(prefs.vibe), 2.8);
    _addText(vector, prefs.budget, 2.0);
    _addText(vector, prefs.season, 1.8);

    if (familyFriendly == true) {
      _addText(vector, 'family safe easy accessible homestay', 2.6);
    } else if (familyFriendly == false) {
      _addText(vector, 'adventure trail difficult independent', 1.4);
    }

    if (adventureLevel != null) {
      if (adventureLevel >= 4) {
        _addText(vector, 'trekking adventure pass ridge high altitude', 2.8);
      } else if (adventureLevel <= 2) {
        _addText(vector, 'easy family village lake peaceful', 2.2);
      } else {
        _addText(vector, 'moderate hike scenic village nature', 1.8);
      }
    }

    return _l2Normalize(vector);
  }

  static void _addText(List<double> vector, String input, double weight) {
    final normalized = _normalize(input);
    if (normalized.isEmpty || weight <= 0) {
      return;
    }

    _addConcepts(vector, normalized, weight);

    final tokens = _tokens(normalized);
    for (final token in tokens) {
      _addHashFeature(vector, token, weight);
    }

    for (var index = 0; index < tokens.length - 1; index++) {
      _addHashFeature(vector, '${tokens[index]} ${tokens[index + 1]}', weight);
    }
  }

  static void _addConcepts(List<double> vector, String text, double weight) {
    for (var index = 0; index < _conceptLexicon.length; index++) {
      var conceptScore = 0.0;
      for (final phrase in _conceptLexicon[index]) {
        final normalizedPhrase = _normalize(phrase);
        if (text == normalizedPhrase) {
          conceptScore += 1.0;
        } else if (text.contains(normalizedPhrase)) {
          conceptScore += 0.82;
        }
      }
      if (conceptScore > 0) {
        vector[index] += weight * min(conceptScore, 2.4);
      }
    }
  }

  static void _addLevel(
    List<double> vector,
    int conceptIndex,
    int? value,
    double weight,
  ) {
    if (value == null || conceptIndex >= _conceptDimensions) {
      return;
    }
    vector[conceptIndex] += (value.clamp(1, 5) / 5.0) * weight;
  }

  static void _addHashFeature(
      List<double> vector, String token, double weight) {
    if (token.isEmpty) return;
    final hash = _stableHash(token);
    final index = _conceptDimensions + hash % (dimension - _conceptDimensions);
    final strength = 0.35 + ((hash >> 8) & 0xff) / 255.0 * 0.65;
    vector[index] += weight * strength;
  }

  static List<String> _tokens(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toList();
  }

  static String _expandedActivity(String activity) {
    switch (_normalize(activity)) {
      case 'trekking':
      case 'hiking':
        return 'trekking hiking trail ridge mountain pass viewpoint adventure';
      case 'adventure':
        return 'adventure trekking climbing cave pass high altitude thrill';
      case 'culture':
      case 'cultural':
        return 'culture heritage village homestay traditional local food';
      case 'pilgrimage':
        return 'pilgrimage temple spiritual dham gumba monastery';
      case 'wildlife':
        return 'wildlife birding forest conservation wetland nature';
      case 'boating':
      case 'lake':
        return 'lake boating waterside scenic family relaxation';
      case 'photography':
        return 'photography viewpoint panorama scenic sunrise mountain view';
      case 'relaxation':
        return 'relaxation peaceful quiet retreat lake village hot spring';
      default:
        return activity;
    }
  }

  static String _expandedVibe(String vibe) {
    switch (_normalize(vibe)) {
      case 'family':
        return 'family safe easy accessible picnic homestay';
      case 'adventure':
        return 'adventure trekking trail climbing pass';
      case 'cultural':
      case 'historic':
        return 'culture heritage traditional history market village';
      case 'spiritual':
        return 'spiritual pilgrimage temple monastery peaceful';
      case 'nature':
        return 'nature forest river lake valley wildlife';
      case 'scenic':
        return 'scenic viewpoint panorama photography sunrise';
      case 'peaceful':
      case 'quiet':
        return 'peaceful quiet retreat relax village slow travel';
      default:
        return vibe;
    }
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _stableHash(String input) {
    const fnvPrime = 16777619;
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  static List<double> _l2Normalize(List<double> vector) {
    final magnitude = sqrt(
      vector.fold(0.0, (sum, value) => sum + value * value),
    );
    if (magnitude == 0) {
      return vector;
    }
    return vector.map((value) => value / magnitude).toList();
  }
}
