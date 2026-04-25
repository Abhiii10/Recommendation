import '../../models/destination.dart';
import '../../models/recommendation_components.dart';

class RecommendationResult {
  final Destination destination;
  final double score;
  final List<String> reasons;
  final RecommendationComponents components;

  const RecommendationResult({
    required this.destination,
    required this.score,
    required this.reasons,
    this.components = const RecommendationComponents.empty(),
  });
}
