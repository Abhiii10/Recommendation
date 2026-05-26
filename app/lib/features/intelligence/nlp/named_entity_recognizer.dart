import '../models/entity_mention.dart';
import '../utils/text_utils.dart';

class NamedEntityRecognizer {
  final Map<String, String> destinationGazetteer;
  final Map<String, String> accommodationGazetteer;

  const NamedEntityRecognizer({
    this.destinationGazetteer = const {},
    this.accommodationGazetteer = const {},
  });

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
    for (final entry in gazetteer.entries) {
      final name = TextUtils.normalizeSearchText(entry.key);
      if (name.length < 3 || !TextUtils.containsPhrase(normalized, name)) {
        continue;
      }
      final start = normalized.indexOf(name);
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
