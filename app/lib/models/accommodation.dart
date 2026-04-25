class Accommodation {
  final String id;
  final String destinationName;
  final String? destinationId;
  final String name;
  final String? type;
  final String? priceRange;
  final List<String> amenities;
  final String? phone;
  final String? locationNote;
  final String source;
  final String confidence;

  const Accommodation({
    required this.id,
    required this.destinationName,
    this.destinationId,
    required this.name,
    this.type,
    this.priceRange,
    required this.amenities,
    this.phone,
    this.locationNote,
    required this.source,
    required this.confidence,
  });

  factory Accommodation.fromJson(Map<String, dynamic> json) {
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

    return Accommodation(
      id: (json['id'] ?? '').toString(),
      destinationName: (json['destination_name'] ?? '').toString(),
      destinationId: json['destination_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      type: json['type']?.toString(),
      priceRange: json['price_range']?.toString(),
      amenities: toStringList(json['amenities']),
      phone: json['phone']?.toString(),
      locationNote: json['location_note']?.toString(),
      source: (json['source'] ?? '').toString(),
      confidence: (json['confidence'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination_name': destinationName,
      'destination_id': destinationId,
      'name': name,
      'type': type,
      'price_range': priceRange,
      'amenities': amenities,
      'phone': phone,
      'location_note': locationNote,
      'source': source,
      'confidence': confidence,
    };
  }
}