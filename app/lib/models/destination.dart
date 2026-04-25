class Destination {
  final String id;
  final String name;
  final String province;
  final String? district;
  final String? municipality;

  final List<String> category;
  final List<String> activities;
  final List<String> bestSeason;
  final String? budgetLevel;
  final String? accessibility;

  final bool? familyFriendly;
  final int? adventureLevel;
  final int? cultureLevel;
  final int? natureLevel;

  final String shortDescription;
  final String fullDescription;

  final double? latitude;
  final double? longitude;

  final List<String> tags;
  final String source;
  final String confidence;

  const Destination({
    required this.id,
    required this.name,
    required this.province,
    this.district,
    this.municipality,
    required this.category,
    required this.activities,
    required this.bestSeason,
    this.budgetLevel,
    this.accessibility,
    this.familyFriendly,
    this.adventureLevel,
    this.cultureLevel,
    this.natureLevel,
    required this.shortDescription,
    required this.fullDescription,
    this.latitude,
    this.longitude,
    required this.tags,
    required this.source,
    required this.confidence,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    List<String> toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return value
          .toString()
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return Destination(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      district: json['district']?.toString(),
      municipality: json['municipality']?.toString(),
      category: toStringList(json['category']),
      activities: toStringList(json['activities']),
      bestSeason: toStringList(json['best_season']),
      budgetLevel: json['budget_level']?.toString(),
      accessibility: json['accessibility']?.toString(),
      familyFriendly:
          json['family_friendly'] is bool ? json['family_friendly'] as bool : null,
      adventureLevel: toInt(json['adventure_level']),
      cultureLevel: toInt(json['culture_level']),
      natureLevel: toInt(json['nature_level']),
      shortDescription: (json['short_description'] ?? '').toString(),
      fullDescription: (json['full_description'] ?? '').toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      tags: toStringList(json['tags']),
      source: (json['source'] ?? '').toString(),
      confidence: (json['confidence'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'district': district,
      'municipality': municipality,
      'category': category,
      'activities': activities,
      'best_season': bestSeason,
      'budget_level': budgetLevel,
      'accessibility': accessibility,
      'family_friendly': familyFriendly,
      'adventure_level': adventureLevel,
      'culture_level': cultureLevel,
      'nature_level': natureLevel,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
      'source': source,
      'confidence': confidence,
    };
  }

  String get locationText {
    final parts = [
      municipality,
      district,
      province,
    ].where((e) => e != null && e.trim().isNotEmpty).cast<String>().toList();

    return parts.join(', ');
  }

  String get primaryCategory =>
      category.isNotEmpty ? category.first : 'destination';

  String get bestSeasonText =>
      bestSeason.isNotEmpty ? bestSeason.join(', ') : 'All year';

  String get displayDescription =>
      fullDescription.isNotEmpty ? fullDescription : shortDescription;

  // Compatibility getters for old UI code
  String get type => primaryCategory;
  String get description => displayDescription;
  String get amenities => activities.join(' | ');
  String get priceTier => budgetLevel ?? 'unknown';
  String get culturalTags => tags.join(' | ');
  double? get lat => latitude;
  double? get lon => longitude;
  List<String> get amenityList => activities;
  List<String> get culturalTagList => tags;
}