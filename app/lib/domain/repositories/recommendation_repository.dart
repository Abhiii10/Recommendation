import '../../models/destination.dart';
import '../../models/user_preferences.dart';
import '../entities/recommendation_result.dart';
import '../../core/errors/failure.dart';

/// Abstract interface for the recommendation engine.
/// The concrete implementation in data/repositories/ wires TF-IDF + numeric
/// vector + affinity boost together.
abstract interface class RecommendationRepository {
  /// Returns up to [topK] ranked [RecommendationResult]s for [prefs].
  Future<Result<List<RecommendationResult>>> getRecommendations(
    UserPreferences prefs,
    List<Destination> destinations, {
    int topK = 10,
  });

  /// Content-based similar destinations to [seed].
  Future<Result<List<RecommendationResult>>> getSimilarDestinations(
    Destination seed,
    List<Destination> destinations, {
    int topK = 4,
  });
}
