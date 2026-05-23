import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/backend_config.dart';
import '../models/accommodation.dart';
import '../models/api_recommendation_item.dart';
import '../models/destination.dart';
import '../models/unified_recommendation.dart';
import '../models/user_preferences.dart';
import 'local_data_service.dart';
import 'recommendation_api_service.dart';
import 'recommender_service.dart';

const Duration _cacheTtl = Duration(hours: 24);

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
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.none)) return false;
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
    String? userId,
  }) async {
    final effectiveUserId = userId ?? await _stableUserId();
    final cacheKey = _cacheKey(
      activity,
      budget,
      season,
      vibe,
      familyFriendly: familyFriendly,
      adventureLevel: adventureLevel,
      topK: topK,
    );

    try {
      final apiResults = await _apiService.recommend(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        userId: effectiveUserId,
        topK: topK,
      );

      await _saveCache(cacheKey, apiResults);

      return UnifiedRecommendationResponse(
        mode: RecommendationMode.ai,
        results: apiResults.map(_mapApiResult).toList(),
        indicatorLabel: 'AI Online Mode',
        message:
            'Using the online hybrid AI recommender: SBERT retrieval, collaborative filtering, popularity fallback, contextual reranking, and explainable scoring.',
        usedFallback: false,
      );
    } catch (_) {
      final cached = await _loadCache(cacheKey);

      if (cached != null && cached.isNotEmpty) {
        return UnifiedRecommendationResponse(
          mode: RecommendationMode.cached,
          results: cached.map(_mapCachedApiResult).toList(),
          indicatorLabel: 'Cached AI Recommendations',
          message:
              'Backend is unavailable. Showing the last cached AI recommendations for this preference profile.',
          usedFallback: true,
        );
      }

      return _buildOfflineResponse(
        activity: activity,
        budget: budget,
        season: season,
        vibe: vibe,
        familyFriendly: familyFriendly,
        adventureLevel: adventureLevel,
        topK: topK,
      );
    }
  }

  Future<void> logSave(
    UnifiedRecommendationResult result, {
    String? userId,
  }) async {
    if (!result.isAiBacked) {
      return;
    }

    try {
      final effectiveUserId = userId ?? await _stableUserId();

      await _apiService.logInteraction(
        userId: effectiveUserId,
        destinationId: result.destination.id,
        eventType: 'save',
      );
    } catch (_) {
      // Saving should not fail the UI when backend is unavailable.
    }
  }

  UnifiedRecommendationResponse _buildOfflineResponse({
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    required int topK,
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
      results:
          offlineResults.map(UnifiedRecommendationResult.fromOffline).toList(),
      indicatorLabel: 'Advanced Offline Mode',
      message:
          'Using local TF-IDF recommendations with contextual scoring and local user personalization.',
      usedFallback: true,
    );
  }

  String _cacheKey(
    String activity,
    String budget,
    String season,
    String vibe, {
    required bool familyFriendly,
    required int adventureLevel,
    required int topK,
  }) {
    final raw = [
      'ai_cache',
      activity,
      budget,
      season,
      vibe,
      familyFriendly ? 'family' : 'mixed',
      'adv_$adventureLevel',
      'top_$topK',
    ].join('_');
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  Future<void> _saveCache(
    String key,
    List<ApiRecommendationItem> items,
  ) async {
    try {
      await LocalDataService.instance.cacheJsonPayload(
        key,
        items.map((item) => item.toJson()).toList(),
      );
    } catch (_) {
      // Cache writing is best-effort.
    }
  }

  Future<List<ApiRecommendationItem>?> _loadCache(String key) async {
    try {
      final decoded = await LocalDataService.instance.getCachedJsonList(
        key,
        maxAge: _cacheTtl,
      );

      if (decoded == null || decoded.isEmpty) return null;

      return decoded
          .map(
            (entry) => ApiRecommendationItem.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<String> _stableUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var id = prefs.getString('stable_user_id');

      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString('stable_user_id', id);
      }

      return id;
    } catch (_) {
      return 'user_anonymous';
    }
  }

  UnifiedRecommendationResult _mapApiResult(ApiRecommendationItem item) {
    return _mapApiResultWithMode(item, RecommendationMode.ai);
  }

  UnifiedRecommendationResult _mapCachedApiResult(ApiRecommendationItem item) {
    return _mapApiResultWithMode(item, RecommendationMode.cached);
  }

  UnifiedRecommendationResult _mapApiResultWithMode(
    ApiRecommendationItem item,
    RecommendationMode mode,
  ) {
    final destination = _destinationById[item.id.toLowerCase()] ??
        _buildFallbackDestination(item);

    return UnifiedRecommendationResult.fromAi(
      destination: destination,
      item: item,
      mode: mode,
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
