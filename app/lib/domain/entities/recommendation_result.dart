import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/recommendation_components.dart';

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
