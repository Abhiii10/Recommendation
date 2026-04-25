class AccommodationModel {
  final String id;
  final String destinationId;
  final String name;
  final String? accommodationType;
  final String? priceRange;
  final List<String> amenities;
  final String? locationNote;

  const AccommodationModel({
    required this.id,
    required this.destinationId,
    required this.name,
    this.accommodationType,
    this.priceRange,
    this.amenities = const [],
    this.locationNote,
  });

  factory AccommodationModel.fromJson(Map<String, dynamic> json) {
    return AccommodationModel(
      id: json['id'] as String,
      destinationId: json['destination_id'] as String,
      name: json['name'] as String,
      accommodationType: json['accommodation_type'] as String?,
      priceRange: json['price_range'] as String?,
      amenities: ((json['amenities'] as List<dynamic>?) ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(),
      locationNote: json['location_note'] as String?,
    );
  }
}
