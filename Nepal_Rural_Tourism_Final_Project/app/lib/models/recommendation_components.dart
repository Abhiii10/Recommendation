class RecommendationSignal {
  final String key;
  final String label;
  final double value;

  const RecommendationSignal({
    required this.key,
    required this.label,
    required this.value,
  });
}

class RecommendationComponents {
  final double semantic;
  final double collaborative;
  final double activityMatch;
  final double vibeMatch;
  final double seasonMatch;
  final double budgetMatch;
  final double accessibilityFit;
  final double familyFit;
  final double accommodationFit;

  const RecommendationComponents({
    required this.semantic,
    required this.collaborative,
    required this.activityMatch,
    required this.vibeMatch,
    required this.seasonMatch,
    required this.budgetMatch,
    required this.accessibilityFit,
    required this.familyFit,
    required this.accommodationFit,
  });

  const RecommendationComponents.empty()
      : semantic = 0.0,
        collaborative = 0.0,
        activityMatch = 0.0,
        vibeMatch = 0.0,
        seasonMatch = 0.0,
        budgetMatch = 0.0,
        accessibilityFit = 0.0,
        familyFit = 0.0,
        accommodationFit = 0.0;

  factory RecommendationComponents.fromJson(Map<String, dynamic> json) {
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0.0;

    return RecommendationComponents(
      semantic: asDouble('semantic'),
      collaborative: asDouble('collaborative'),
      activityMatch: asDouble('activity_match'),
      vibeMatch: asDouble('vibe_match'),
      seasonMatch: asDouble('season_match'),
      budgetMatch: asDouble('budget_match'),
      accessibilityFit: asDouble('accessibility_fit'),
      familyFit: asDouble('family_fit'),
      accommodationFit: asDouble('accommodation_fit'),
    );
  }

  bool get hasCollaborativeSignal => collaborative > 0.01;

  List<RecommendationSignal> signals({bool includeCollaborative = true}) {
    final items = <RecommendationSignal>[
      RecommendationSignal(
        key: 'semantic',
        label: 'Semantic / Text',
        value: semantic,
      ),
      if (includeCollaborative && hasCollaborativeSignal)
        RecommendationSignal(
          key: 'collaborative',
          label: 'Collaborative',
          value: collaborative,
        ),
      RecommendationSignal(
        key: 'activity_match',
        label: 'Activity Match',
        value: activityMatch,
      ),
      RecommendationSignal(
        key: 'vibe_match',
        label: 'Vibe Match',
        value: vibeMatch,
      ),
      RecommendationSignal(
        key: 'season_match',
        label: 'Season Match',
        value: seasonMatch,
      ),
      RecommendationSignal(
        key: 'budget_match',
        label: 'Budget Match',
        value: budgetMatch,
      ),
      RecommendationSignal(
        key: 'accessibility_fit',
        label: 'Accessibility Fit',
        value: accessibilityFit,
      ),
      RecommendationSignal(
        key: 'family_fit',
        label: 'Family Fit',
        value: familyFit,
      ),
      RecommendationSignal(
        key: 'accommodation_fit',
        label: 'Accommodation Fit',
        value: accommodationFit,
      ),
    ];

    return items.where((signal) => signal.value > 0.0).toList();
  }
}
