import 'package:rural_tourism_app/features/intelligence/models/entity_mention.dart';
import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';

class NamedEntityRecognizer {
  static const _genericDestinationTokens = {
    'area',
    'base',
    'bazaar',
    'camp',
    'community',
    'corridor',
    'cultural',
    'culture',
    'danda',
    'forest',
    'hill',
    'khola',
    'lake',
    'monastery',
    'river',
    'riverside',
    'rural',
    'scenic',
    'spiritual',
    'temple',
    'trail',
    'trek',
    'tourism',
    'valley',
    'village',
    'view',
    'viewpoint',
  };

  final Map<String, String> destinationGazetteer;
  final Map<String, String> accommodationGazetteer;

  NamedEntityRecognizer({
    Map<String, String> destinationGazetteer = const {},
    this.accommodationGazetteer = const {},
  }) : destinationGazetteer = _expandDestinationGazetteer(destinationGazetteer);

  List<EntityMention> recognize(String text) {
    final entities = <EntityMention>[];
    final normalized = TextUtils.normalizeSearchText(text);
    _matchGazetteer(
      text,
      normalized,
      destinationGazetteer,
      EntityType.destination,
      entities,
    );
    _matchGazetteer(
      text,
      normalized,
      accommodationGazetteer,
      EntityType.accommodation,
      entities,
    );
    _matchPatterns(text, entities);
    entities.sort((a, b) => a.start.compareTo(b.start));
    return entities;
  }

  void _matchGazetteer(
    String original,
    String normalized,
    Map<String, String> gazetteer,
    EntityType type,
    List<EntityMention> entities,
  ) {
    final matchedCanonicalIds = <String>{};
    final entries = gazetteer.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in entries) {
      if (matchedCanonicalIds.contains(entry.value)) {
        continue;
      }
      final name = TextUtils.normalizeSearchText(entry.key);
      if (name.length < 3 || !TextUtils.containsPhrase(normalized, name)) {
        continue;
      }
      final start = normalized.indexOf(name);
      matchedCanonicalIds.add(entry.value);
      entities.add(
        EntityMention(
          text: entry.key,
          type: type,
          start: start < 0 ? 0 : start,
          end: start < 0 ? original.length : start + name.length,
          confidence: 0.95,
          canonicalId: entry.value,
        ),
      );
    }
  }

  static Map<String, String> _expandDestinationGazetteer(
    Map<String, String> gazetteer,
  ) {
    final expanded = <String, String>{...gazetteer};
    final tokenOwners = <String, Set<String>>{};

    for (final entry in gazetteer.entries) {
      final tokens = TextUtils.simpleTokens(entry.key)
          .where((token) => !_genericDestinationTokens.contains(token))
          .toList();
      for (final token in tokens) {
        if (token.length < 3) continue;
        tokenOwners.putIfAbsent(token, () => <String>{}).add(entry.value);
      }
      if (tokens.length >= 2) {
        expanded.putIfAbsent(tokens.take(2).join(' '), () => entry.value);
      }
    }

    for (final entry in tokenOwners.entries) {
      if (entry.value.length == 1) {
        expanded.putIfAbsent(entry.key, () => entry.value.first);
      }
    }

    return expanded;
  }

  void _matchPatterns(String text, List<EntityMention> entities) {
    final patterns = <EntityType, RegExp>{
      EntityType.duration: RegExp(
        r'(\d+)\s*(day|days|hour|hours|दिन|घण्टा|din|ghanta)',
        caseSensitive: false,
      ),
      EntityType.money: RegExp(
        r'((npr|rs|रु|रुपैयाँ)\s*)?\d{2,6}\s*(npr|rs|रु|रुपैयाँ)?',
        caseSensitive: false,
      ),
      EntityType.season: RegExp(
        r'\b(spring|autumn|fall|monsoon|winter|summer|बसन्त|शरद|वर्षा|जाडो)\b',
        caseSensitive: false,
      ),
      EntityType.activity: RegExp(
        r'\b(trekking|hiking|rafting|paragliding|boating|culture|pilgrimage|ट्रेकिङ|राफ्टिङ|संस्कृति|तीर्थ)\b',
        caseSensitive: false,
      ),
    };

    for (final entry in patterns.entries) {
      for (final match in entry.value.allMatches(text)) {
        entities.add(
          EntityMention(
            text: match.group(0) ?? '',
            type: entry.key,
            start: match.start,
            end: match.end,
            confidence: 0.86,
          ),
        );
      }
    }
  }
}
