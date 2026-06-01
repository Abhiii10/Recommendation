import 'package:hive/hive.dart';

import 'package:rural_tourism_app/domain/entities/user_interaction.dart'
    as domain;
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart'
    as recommendation;

class CachedRecommendation {
  final String id;
  final List<dynamic> destinations;
  final int timestamp;
  final String preferencesHash;

  const CachedRecommendation({
    required this.id,
    required this.destinations,
    required this.timestamp,
    required this.preferencesHash,
  });

  bool isOlderThan(Duration maxAge) {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > maxAge.inMilliseconds;
  }
}

class CachedRecommendationAdapter extends TypeAdapter<CachedRecommendation> {
  @override
  final int typeId = 31;

  @override
  CachedRecommendation read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final fieldCount = reader.readByte();

    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return CachedRecommendation(
      id: fields[0] as String,
      destinations: List<dynamic>.from(fields[1] as List? ?? const []),
      timestamp: (fields[2] as num?)?.toInt() ?? 0,
      preferencesHash: fields[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, CachedRecommendation obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.destinations)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.preferencesHash);
  }
}

class UserInteractionAdapter extends TypeAdapter<domain.UserInteraction> {
  @override
  final int typeId = 32;

  @override
  domain.UserInteraction read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final fieldCount = reader.readByte();

    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return domain.UserInteraction(
      destinationId: fields[0] as String,
      type: domain.InteractionType.values.firstWhere(
        (type) => type.name == fields[1],
        orElse: () => domain.InteractionType.click,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (fields[2] as num?)?.toInt() ?? 0,
      ),
      categories: List<String>.from(fields[3] as List? ?? const []),
      tags: List<String>.from(fields[4] as List? ?? const []),
    );
  }

  @override
  void write(BinaryWriter writer, domain.UserInteraction obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.destinationId)
      ..writeByte(1)
      ..write(obj.type.name)
      ..writeByte(2)
      ..write(obj.timestamp.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.categories)
      ..writeByte(4)
      ..write(obj.tags);
  }
}

class UserPreferencesAdapter
    extends TypeAdapter<recommendation.UserPreferences> {
  @override
  final int typeId = 33;

  @override
  recommendation.UserPreferences read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final fieldCount = reader.readByte();

    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return recommendation.UserPreferences(
      activity: fields[0] as String? ?? '',
      budget: fields[1] as String? ?? '',
      season: fields[2] as String? ?? '',
      vibe: fields[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, recommendation.UserPreferences obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.activity)
      ..writeByte(1)
      ..write(obj.budget)
      ..writeByte(2)
      ..write(obj.season)
      ..writeByte(3)
      ..write(obj.vibe);
  }
}
