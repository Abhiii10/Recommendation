import 'recommendation_components.dart';

class ApiRecommendationItem {
  final String id;
  final String name;
  final String? district;
  final String? province;
  final double score;
  final RecommendationComponents components;
  final List<String> reasons;
  final Map<String, String> metadata;

  const ApiRecommendationItem({
    required this.id,
    required this.name,
    this.district,
    this.province,
    required this.score,
    required this.components,
    required this.reasons,
    this.metadata = const {},
  });

  factory ApiRecommendationItem.fromJson(Map<String, dynamic> json) {
    return ApiRecommendationItem(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String?,
      province: json['province'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      components: RecommendationComponents.fromJson(
        (json['components'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      reasons: ((json['reasons'] as List<dynamic>?) ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(),
      metadata:
          ((json['metadata'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{})
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  String get location {
    final parts = [district, province].whereType<String>().toList();
    return parts.join(', ');
  }

  String get budgetLevel => metadata['budget_level'] ?? '';

  String get accessibility => metadata['accessibility'] ?? '';
}
