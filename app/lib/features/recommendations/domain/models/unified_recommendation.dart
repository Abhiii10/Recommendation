import 'package:rural_tourism_app/domain/entities/recommendation_result.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/api_recommendation_item.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/recommendation_components.dart';

enum RecommendationMode {
  ai,
  cached,
  offline,
}

class UnifiedRecommendationResult {
  final Destination destination;
  final double score;
  final List<String> reasons;
  final RecommendationComponents components;
  final RecommendationMode mode;
  final ApiRecommendationItem? aiItem;

  const UnifiedRecommendationResult({
    required this.destination,
    required this.score,
    required this.reasons,
    required this.components,
    required this.mode,
    this.aiItem,
  });

  factory UnifiedRecommendationResult.fromOffline(
    RecommendationResult result,
  ) {
    return UnifiedRecommendationResult(
      destination: result.destination,
      score: result.score,
      reasons: result.reasons,
      components: result.components,
      mode: RecommendationMode.offline,
    );
  }

  factory UnifiedRecommendationResult.fromAi({
    required Destination destination,
    required ApiRecommendationItem item,
    RecommendationMode mode = RecommendationMode.ai,
  }) {
    return UnifiedRecommendationResult(
      destination: destination,
      score: item.score,
      reasons: item.reasons,
      components: item.components,
      mode: mode,
      aiItem: item,
    );
  }

  bool get isAiBacked {
    return (mode == RecommendationMode.ai ||
            mode == RecommendationMode.cached) &&
        aiItem != null;
  }

  String get modeLabel {
    switch (mode) {
      case RecommendationMode.ai:
        return 'AI Online Mode';
      case RecommendationMode.cached:
        return 'Cached AI';
      case RecommendationMode.offline:
        return 'Advanced Offline Mode';
    }
  }
}

class UnifiedRecommendationResponse {
  final RecommendationMode mode;
  final List<UnifiedRecommendationResult> results;
  final String indicatorLabel;
  final String message;
  final bool usedFallback;

  const UnifiedRecommendationResponse({
    required this.mode,
    required this.results,
    required this.indicatorLabel,
    required this.message,
    required this.usedFallback,
  });
}
