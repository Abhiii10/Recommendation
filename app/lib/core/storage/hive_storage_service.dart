import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:rural_tourism_app/core/storage/hive_models.dart';
import 'package:rural_tourism_app/domain/entities/user_interaction.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/user_preferences.dart';

class HiveStorageService {
  HiveStorageService._();

  static final HiveStorageService instance = HiveStorageService._();

  static const String recommendationCacheBoxName = 'recommendation_cache_v1';
  static const String pendingInteractionsBoxName =
      'pending_backend_interactions_v1';
  static const String userInteractionsBoxName = 'user_interactions_v1';
  static const String userPreferencesBoxName = 'user_preferences_v1';

  bool _initialized = false;

  late Box<CachedRecommendation> _recommendationCacheBox;
  late Box<dynamic> _pendingInteractionsBox;
  late Box<UserInteraction> _userInteractionsBox;
  late Box<UserPreferences> _userPreferencesBox;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _registerAdapters();

    _recommendationCacheBox =
        await Hive.openBox<CachedRecommendation>(recommendationCacheBoxName);
    _pendingInteractionsBox =
        await Hive.openBox<dynamic>(pendingInteractionsBoxName);
    _userInteractionsBox =
        await Hive.openBox<UserInteraction>(userInteractionsBoxName);
    _userPreferencesBox =
        await Hive.openBox<UserPreferences>(userPreferencesBoxName);

    _initialized = true;
  }

  Future<void> cacheRecommendationsJson(
    String cacheKey,
    Object payload, {
    String? preferencesHash,
  }) async {
    await init();

    final normalized = jsonDecode(jsonEncode(payload));
    final destinations =
        normalized is List ? List<dynamic>.from(normalized) : <dynamic>[];

    await _recommendationCacheBox.put(
      cacheKey,
      CachedRecommendation(
        id: cacheKey,
        destinations: destinations,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        preferencesHash: preferencesHash ?? cacheKey,
      ),
    );
  }

  Future<CachedRecommendation?> getCachedRecommendation(String cacheKey) async {
    await init();
    return _recommendationCacheBox.get(cacheKey);
  }

  Future<List<dynamic>?> getCachedRecommendationsJson(
    String cacheKey, {
    Duration? maxAge,
    bool allowStale = false,
  }) async {
    final entry = await getCachedRecommendation(cacheKey);
    if (entry == null) return null;

    if (maxAge != null && entry.isOlderThan(maxAge) && !allowStale) {
      return null;
    }

    return List<dynamic>.from(entry.destinations);
  }

  Future<void> clearRecommendationCache() async {
    await init();
    await _recommendationCacheBox.clear();
  }

  Future<void> saveUserInteraction(UserInteraction interaction) async {
    await init();
    final key =
        '${interaction.timestamp.microsecondsSinceEpoch}_${interaction.destinationId}_${interaction.type.name}';
    await _userInteractionsBox.put(key, interaction);
  }

  Future<int> getUserInteractionCount() async {
    await init();
    return _userInteractionsBox.length;
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await init();
    await _userPreferencesBox.put('current', preferences);
  }

  Future<UserPreferences?> getUserPreferences() async {
    await init();
    return _userPreferencesBox.get('current');
  }

  Future<void> enqueuePendingBackendInteraction(
    Map<String, dynamic> item,
  ) async {
    await init();
    await _pendingInteractionsBox.put(item['id'].toString(), item);
  }

  Future<List<Map<String, dynamic>>> getPendingBackendInteractions({
    int limit = 50,
  }) async {
    await init();

    final items = _pendingInteractionsBox.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) {
        final aCreated = (a['created_at'] as num?)?.toInt() ?? 0;
        final bCreated = (b['created_at'] as num?)?.toInt() ?? 0;
        return aCreated.compareTo(bCreated);
      });

    return items.take(limit).toList();
  }

  Future<void> removePendingBackendInteractions(List<String> ids) async {
    if (ids.isEmpty) return;

    await init();
    await _pendingInteractionsBox.deleteAll(ids);
  }

  Future<void> markPendingBackendInteractionsAttempted(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;

    await init();

    for (final id in ids) {
      final raw = _pendingInteractionsBox.get(id);
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);
      item['attempts'] = ((item['attempts'] as num?)?.toInt() ?? 0) + 1;
      await _pendingInteractionsBox.put(id, item);
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(CachedRecommendationAdapter());
    }
    if (!Hive.isAdapterRegistered(32)) {
      Hive.registerAdapter(UserInteractionAdapter());
    }
    if (!Hive.isAdapterRegistered(33)) {
      Hive.registerAdapter(UserPreferencesAdapter());
    }
  }
}
