class UserProfile {
  final Map<String, double> categoryAffinity;
  final Map<String, double> tagAffinity;
  final int interactionCount;

  const UserProfile({
    required this.categoryAffinity,
    required this.tagAffinity,
    required this.interactionCount,
  });

  factory UserProfile.empty() => const UserProfile(
        categoryAffinity: {},
        tagAffinity: {},
        interactionCount: 0,
      );

  Map<String, dynamic> toJson() => {
        'category_affinity': categoryAffinity,
        'tag_affinity': tagAffinity,
        'interaction_count': interactionCount,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    Map<String, double> toDoubleMap(dynamic raw) {
      if (raw == null) return {};
      final map = raw as Map;
      return {
        for (final e in map.entries)
          e.key.toString(): (e.value as num).toDouble(),
      };
    }

    return UserProfile(
      categoryAffinity: toDoubleMap(json['category_affinity']),
      tagAffinity: toDoubleMap(json['tag_affinity']),
      interactionCount: (json['interaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}