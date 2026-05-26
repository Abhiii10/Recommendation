enum EntityType {
  destination,
  accommodation,
  duration,
  money,
  activity,
  season,
  location,
  unknown,
}

class EntityMention {
  final String text;
  final EntityType type;
  final int start;
  final int end;
  final double confidence;
  final String? canonicalId;
  final Map<String, dynamic> metadata;

  const EntityMention({
    required this.text,
    required this.type,
    required this.start,
    required this.end,
    required this.confidence,
    this.canonicalId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'type': type.name,
        'start': start,
        'end': end,
        'confidence': confidence,
        'canonical_id': canonicalId,
        'metadata': metadata,
      };
}
