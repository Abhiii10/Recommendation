import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import 'package:rural_tourism_app/core/data/local_data_service.dart';
import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommendation_manager.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommender_service.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/unified_recommendation.dart';
import 'package:rural_tourism_app/providers/user_prefs_provider.dart';

class RecommendationsState {
  final bool isLoading;
  final bool checkingBackend;
  final bool backendAvailable;
  final bool backendOffline;
  final bool checkingHealth;
  final String? error;
  final UnifiedRecommendationResponse? response;
  final List<Destination> localDestinations;
  final List<Accommodation> localAccommodations;
  final int revision;

  const RecommendationsState({
    this.isLoading = false,
    this.checkingBackend = true,
    this.backendAvailable = false,
    this.backendOffline = false,
    this.checkingHealth = false,
    this.error,
    this.response,
    this.localDestinations = const [],
    this.localAccommodations = const [],
    this.revision = 0,
  });

  RecommendationsState copyWith({
    bool? isLoading,
    bool? checkingBackend,
    bool? backendAvailable,
    bool? backendOffline,
    bool? checkingHealth,
    Object? error = _sentinel,
    UnifiedRecommendationResponse? response,
    bool clearResponse = false,
    List<Destination>? localDestinations,
    List<Accommodation>? localAccommodations,
    int? revision,
  }) {
    return RecommendationsState(
      isLoading: isLoading ?? this.isLoading,
      checkingBackend: checkingBackend ?? this.checkingBackend,
      backendAvailable: backendAvailable ?? this.backendAvailable,
      backendOffline: backendOffline ?? this.backendOffline,
      checkingHealth: checkingHealth ?? this.checkingHealth,
      error: identical(error, _sentinel) ? this.error : error as String?,
      response: clearResponse ? null : response ?? this.response,
      localDestinations: localDestinations ?? this.localDestinations,
      localAccommodations: localAccommodations ?? this.localAccommodations,
      revision: revision ?? this.revision,
    );
  }

  List<Destination> destinationsFor(List<Destination> fallback) {
    return backendOffline && localDestinations.isNotEmpty
        ? localDestinations
        : fallback;
  }

  List<Accommodation> accommodationsFor(List<Accommodation> fallback) {
    return backendOffline && localAccommodations.isNotEmpty
        ? localAccommodations
        : fallback;
  }
}

class RecommendationsNotifier extends StateNotifier<RecommendationsState> {
  RecommendationsNotifier() : super(const RecommendationsState());

  RecommendationManager? _manager;
  RecommenderService? _service;
  List<Destination> _destinations = const [];
  List<Accommodation> _accommodations = const [];
  String? _signature;

  Future<void> configure({
    required RecommenderService service,
    required List<Destination> destinations,
    required List<Accommodation> accommodations,
  }) async {
    final signature = '${identityHashCode(service)}:'
        '${destinations.length}:${accommodations.length}';

    _service = service;
    _destinations = destinations;
    _accommodations = accommodations;

    if (_signature == signature && _manager != null) {
      return;
    }

    _signature = signature;
    _manager = _buildManager();
    await checkHealth();
  }

  Future<void> checkHealth() async {
    if (state.checkingHealth) return;

    state = state.copyWith(
      checkingHealth: true,
      checkingBackend: true,
    );

    final result = await BackendConfig.checkBackendHealth(attempts: 1);
    final localDestinations = result.reachable
        ? const <Destination>[]
        : await LocalDataService.instance.loadLocalDestinations();
    final localAccommodations = result.reachable
        ? const <Accommodation>[]
        : await LocalDataService.instance.loadLocalAccommodations();

    state = state.copyWith(
      backendOffline: !result.reachable,
      localDestinations: localDestinations,
      localAccommodations: localAccommodations,
      backendAvailable: result.reachable,
      checkingBackend: false,
      checkingHealth: false,
    );

    _manager = _buildManager();
  }

  Future<void> generate(RecommendationPrefsState prefs) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final manager = _manager ?? _buildManager();
      final response = state.backendOffline
          ? manager.recommendOffline(
              activity: prefs.activity,
              budget: prefs.budget,
              season: prefs.season,
              vibe: prefs.vibe,
              familyFriendly: prefs.familyFriendly,
              adventureLevel: prefs.adventureLevel,
              topK: 10,
            )
          : await manager.recommend(
              activity: prefs.activity,
              budget: prefs.budget,
              season: prefs.season,
              vibe: prefs.vibe,
              familyFriendly: prefs.familyFriendly,
              adventureLevel: prefs.adventureLevel,
              topK: 10,
            );

      state = state.copyWith(
        response: response,
        isLoading: false,
        backendAvailable: response.mode == RecommendationMode.ai,
      );

      unawaited(manager.logRecommendationShown(response.results));
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not generate recommendations.\n\n$e',
      );
    }
  }

  Future<void> refreshResults(RecommendationPrefsState prefs) async {
    await LocalDataService.instance.clearRecommendationCache();
    await generate(prefs);
  }

  Future<void> logSave(
    UnifiedRecommendationResult result, {
    required bool saved,
  }) async {
    try {
      await (_manager ?? _buildManager()).logSave(result, saved: saved);
    } catch (_) {}
    notifySavedStateChanged();
  }

  Future<void> logClick(UnifiedRecommendationResult result) async {
    try {
      await (_manager ?? _buildManager()).logClick(result);
    } catch (_) {}
  }

  void notifySavedStateChanged() {
    state = state.copyWith(revision: state.revision + 1);
  }

  RecommendationManager _buildManager() {
    final manager = RecommendationManager(
      offlineService: _service!,
      destinations: state.destinationsFor(_destinations),
      accommodations: state.accommodationsFor(_accommodations),
    );
    _manager = manager;
    return manager;
  }
}

const Object _sentinel = Object();

final recommendationsProvider =
    StateNotifierProvider<RecommendationsNotifier, RecommendationsState>(
  (ref) => RecommendationsNotifier(),
);
