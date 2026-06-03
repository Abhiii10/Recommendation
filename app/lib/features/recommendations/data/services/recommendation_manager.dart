import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:rural_tourism_app/config/app_config.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/api_recommendation_item.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/unified_recommendation.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';
import 'package:rural_tourism_app/features/auth/data/services/auth_session_service.dart';
import 'package:rural_tourism_app/core/sync/interaction_sync_service.dart';
import 'package:rural_tourism_app/core/data/local_data_service.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommendation_api_service.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommender_service.dart';

const Duration _cacheTtl = Duration(hours: 24);

class CachedApiRecommendations {
  final List<ApiRecommendationItem> items;
  final bool isStale;

  const CachedApiRecommendations({
    required this.items,
    required this.isStale,
  });
}

class RecommendationManager {
  final RecommendationApiService _apiService;
  final RecommenderService _offlineService;
  final List<Destination> _destinations;
  final List<Accommodation> _accommodations;
  final InteractionSyncService _interactionSyncService;
  late final Map<String, Destination> _destinationById;

  RecommendationManager({
    required RecommenderService offlineService,
    required List<Destination> destinations,
    required List<Accommodation> accommodations,
    RecommendationApiService? apiService,
    InteractionSyncService? interactionSyncService,
  })  : _offlineService = offlineService,
        _destinations = destinations,
        _accommodations = accommodations,
        _interactionSyncService =
            interactionSyncService ?? InteractionSyncService.instance,
        _apiService =
            apiService ?? RecommendationApiService(baseUrl: AppConfig.baseUrl) {
    _destinationById = {
      for (final destination in _destinations)
        destination.id.toLowerCase(): destination,
    };
  }

  Future<bool> isBackendAvailable() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.none)) return false;
      final healthy = await _apiService.isHealthy();
      if (healthy) {
        unawaited(_interactionSyncService.syncPending());
      }
      return healthy;
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

      if (cached != null && cached.items.isNotEmpty) {
        if (cached.isStale) {
          unawaited(
            _refreshStaleCache(
              cacheKey: cacheKey,
              activity: activity,
              budget: budget,
              season: season,
              vibe: vibe,
              familyFriendly: familyFriendly,
              adventureLevel: adventureLevel,
              userId: effectiveUserId,
              topK: topK,
            ),
          );
        }

        return UnifiedRecommendationResponse(
          mode: RecommendationMode.cached,
          results: cached.items.map(_mapCachedApiResult).toList(),
          indicatorLabel: cached.isStale
              ? 'Stale Cached AI Recommendations'
              : 'Cached AI Recommendations',
          message: cached.isStale
              ? 'Cached recommendations are older than 24 hours. Showing them now and refreshing in the background when online.'
              : 'Backend is unavailable. Showing the last cached AI recommendations for this preference profile.',
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

  UnifiedRecommendationResponse recommendOffline({
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    int topK = 10,
  }) {
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

  Future<void> logSave(
    UnifiedRecommendationResult result, {
    String? userId,
    bool saved = true,
  }) async {
    if (!result.isAiBacked) {
      return;
    }

    try {
      final effectiveUserId = userId ?? await _stableUserId();

      await _interactionSyncService.recordInteraction(
        userId: effectiveUserId,
        destinationId: result.destination.id,
        eventType: saved ? 'save' : 'unsave',
        recommendationId: result.aiItem?.metadata['recommendation_id'],
        pipelineUsed: result.aiItem?.metadata['pipeline_used'],
      );
    } catch (_) {
      // Saving should not fail the UI when backend is unavailable.
    }
  }

  Future<void> logRecommendationShown(
    List<UnifiedRecommendationResult> results, {
    String? userId,
  }) async {
    final aiResults = results
        .where(
          (result) =>
              result.isAiBacked &&
              result.aiItem?.metadata['server_logged_impression'] != 'true',
        )
        .toList();

    if (aiResults.isEmpty) {
      return;
    }

    try {
      final effectiveUserId = userId ?? await _stableUserId();

      await Future.wait(
        aiResults.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final result = entry.value;

          return _interactionSyncService.recordInteraction(
            userId: effectiveUserId,
            destinationId: result.destination.id,
            eventType: 'recommendation_shown',
            value: 1.0 / rank,
          );
        }),
      );
    } catch (_) {
      // Impression logging should not fail recommendation display.
    }
  }

  Future<void> logClick(
    UnifiedRecommendationResult result, {
    String? userId,
  }) async {
    if (!result.isAiBacked) {
      return;
    }

    try {
      final effectiveUserId = userId ?? await _stableUserId();

      await _interactionSyncService.recordInteraction(
        userId: effectiveUserId,
        destinationId: result.destination.id,
        eventType: 'click',
        recommendationId: result.aiItem?.metadata['recommendation_id'],
        pipelineUsed: result.aiItem?.metadata['pipeline_used'],
      );
    } catch (_) {
      // Click logging should never block navigation.
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
          'Using offline semantic embeddings, contextual scoring, nearby stays, and local personalization.',
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
        items.map((item) => _withoutEvaluationMetadata(item).toJson()).toList(),
      );
    } catch (_) {
      // Cache writing is best-effort.
    }
  }

  Future<CachedApiRecommendations?> _loadCache(String key) async {
    try {
      final entry =
          await LocalDataService.instance.getCachedRecommendationEntry(key);
      if (entry == null) return null;

      final decoded = await LocalDataService.instance.getCachedJsonList(
        key,
        maxAge: _cacheTtl,
        allowStale: true,
      );

      if (decoded == null || decoded.isEmpty) return null;

      final items = decoded
          .map(
            (item) => ApiRecommendationItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      return CachedApiRecommendations(
        items: items,
        isStale: entry.isOlderThan(_cacheTtl),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshStaleCache({
    required String cacheKey,
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    required String userId,
    required int topK,
  }) async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.none)) return;

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

      await _saveCache(cacheKey, apiResults);
    } catch (_) {
      // Stale refresh is opportunistic and should never affect the UI.
    }
  }

  Future<String> _stableUserId() async {
    try {
      final authenticatedUserId =
          await AuthSessionService.instance.currentUserId();
      if (authenticatedUserId != null && authenticatedUserId.isNotEmpty) {
        return authenticatedUserId;
      }

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

  ApiRecommendationItem _withoutEvaluationMetadata(ApiRecommendationItem item) {
    final metadata = Map<String, String>.from(item.metadata)
      ..remove('recommendation_id')
      ..remove('pipeline_used')
      ..remove('server_logged_impression');

    return item.copyWith(metadata: metadata);
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
