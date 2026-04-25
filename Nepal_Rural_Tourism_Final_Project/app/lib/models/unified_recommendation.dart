import '../domain/entities/recommendation_result.dart';
import 'api_recommendation_item.dart';
import 'destination.dart';
import 'recommendation_components.dart';

enum RecommendationMode {
  ai,
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
  }) {
    return UnifiedRecommendationResult(
      destination: destination,
      score: item.score,
      reasons: item.reasons,
      components: item.components,
      mode: RecommendationMode.ai,
      aiItem: item,
    );
  }

  bool get isAiBacked => mode == RecommendationMode.ai && aiItem != null;

  String get modeLabel => mode == RecommendationMode.ai
      ? 'AI Online Mode'
      : 'Advanced Offline Mode';
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
