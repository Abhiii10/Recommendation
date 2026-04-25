import '../core/utils/backend_config.dart';
import '../models/accommodation.dart';
import '../models/api_recommendation_item.dart';
import '../models/destination.dart';
import '../models/unified_recommendation.dart';
import '../models/user_preferences.dart';
import 'recommendation_api_service.dart';
import 'recommender_service.dart';

class RecommendationManager {
  final RecommendationApiService _apiService;
  final RecommenderService _offlineService;
  final List<Destination> _destinations;
  final List<Accommodation> _accommodations;
  late final Map<String, Destination> _destinationById;

  RecommendationManager({
    required RecommenderService offlineService,
    required List<Destination> destinations,
    required List<Accommodation> accommodations,
    RecommendationApiService? apiService,
  })  : _offlineService = offlineService,
        _destinations = destinations,
        _accommodations = accommodations,
        _apiService =
            apiService ?? RecommendationApiService(baseUrl: backendBaseUrl) {
    _destinationById = {
      for (final destination in _destinations)
        destination.id.toLowerCase(): destination,
    };
  }

  Future<bool> isBackendAvailable() async {
    try {
      return await _apiService.isHealthy();
    } catch (_) {
      return false;
    }
  }

  Future<UnifiedRecommendationResponse> recommend({
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    int topK = 10,
    String userId = 'demo_user_1',
  }) async {
    try {
      final apiResults = await _apiService.recommend(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        userId: userId,
        topK: topK,
      );

      return UnifiedRecommendationResponse(
        mode: RecommendationMode.ai,
        results: apiResults.map(_mapApiResult).toList(),
        indicatorLabel: 'AI Online Mode',
        message:
            'Using the backend AI recommender with semantic retrieval, reranking, and explainable score factors.',
        usedFallback: false,
      );
    } catch (_) {
      return _buildOfflineResponse(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        topK: topK,
        message:
            'Using advanced offline recommendations because the backend is unavailable.',
        usedFallback: true,
      );
    }
  }

  Future<void> logSave(
    UnifiedRecommendationResult result, {
    String userId = 'demo_user_1',
  }) async {
    if (!result.isAiBacked) {
      return;
    }

    await _apiService.logInteraction(
      userId: userId,
      destinationId: result.destination.id,
      eventType: 'save',
    );
  }

  UnifiedRecommendationResponse _buildOfflineResponse({
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    required int topK,
    required String message,
    required bool usedFallback,
  }) {
    final preferences = UserPreferences(
      activity: _mapActivityForOffline(activity),
      budget: budget,
      season: season,
      vibe: _mapVibeForOffline(vibe),
    );

    final offlineResults = _offlineService.recommendByPreferences(
      preferences,
      _destinations,
      accommodations: _accommodations,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
      topK: topK,
    );

    return UnifiedRecommendationResponse(
      mode: RecommendationMode.offline,
      results: offlineResults
          .map(UnifiedRecommendationResult.fromOffline)
          .toList(),
      indicatorLabel: 'Advanced Offline Mode',
      message: message,
      usedFallback: usedFallback,
    );
  }

  UnifiedRecommendationResult _mapApiResult(ApiRecommendationItem item) {
    final destination = _destinationById[item.id.toLowerCase()] ??
        _buildFallbackDestination(item);

    return UnifiedRecommendationResult.fromAi(
      destination: destination,
      item: item,
    );
  }

  Destination _buildFallbackDestination(ApiRecommendationItem item) {
    return Destination(
      id: item.id,
      name: item.name,
      province: item.province ?? '',
      district: item.district,
      municipality: null,
      category: const ['destination'],
      activities: const [],
      bestSeason: const [],
      budgetLevel: item.budgetLevel.isEmpty ? null : item.budgetLevel,
      accessibility: item.accessibility.isEmpty ? null : item.accessibility,
      familyFriendly: null,
      adventureLevel: null,
      cultureLevel: null,
      natureLevel: null,
      shortDescription: item.reasons.isNotEmpty
          ? item.reasons.first
          : 'Recommended by the AI backend.',
      fullDescription: item.reasons.join(' '),
      latitude: null,
      longitude: null,
      tags: item.reasons,
      source: 'backend',
      confidence: 'api',
    );
  }

  String _mapActivityForOffline(String value) {
    switch (value) {
      case 'trekking':
        return 'hiking';
      case 'boating':
        return 'lake';
      case 'pilgrimage':
        return 'culture';
      default:
        return value;
    }
  }

  String _mapVibeForOffline(String value) {
    switch (value) {
      case 'spiritual':
      case 'nature':
        return 'quiet';
      case 'scenic':
        return 'photography';
      case 'historic':
        return 'cultural';
      case 'social':
        return 'family';
      default:
        return value;
    }
  }
}
