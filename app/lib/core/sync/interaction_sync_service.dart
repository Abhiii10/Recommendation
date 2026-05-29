import 'dart:async';

import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/core/data/local_data_service.dart';
import 'package:rural_tourism_app/features/recommendations/data/services/recommendation_api_service.dart';

class InteractionSyncService {
  InteractionSyncService({
    RecommendationApiService? apiService,
    LocalDataService? localDataService,
  })  : _apiService =
            apiService ?? RecommendationApiService(baseUrl: backendBaseUrl),
        _localDataService = localDataService ?? LocalDataService.instance;

  static final InteractionSyncService instance = InteractionSyncService();

  final RecommendationApiService _apiService;
  final LocalDataService _localDataService;

  bool _syncing = false;

  Future<void> recordInteraction({
    required String userId,
    required String destinationId,
    required String eventType,
    double value = 1.0,
    DateTime? timestamp,
    bool syncNow = true,
  }) async {
    await _localDataService.enqueueBackendInteraction(
      userId: userId,
      destinationId: destinationId,
      eventType: eventType,
      value: value,
      timestamp: (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
    );

    if (syncNow) {
      unawaited(syncPending());
    }
  }

  Future<int> syncPending({int limit = 50}) async {
    if (_syncing) {
      return 0;
    }

    _syncing = true;

    try {
      final pending = await _localDataService.getPendingBackendInteractions(
        limit: limit,
      );

      if (pending.isEmpty) {
        return 0;
      }

      final ids = pending.map((item) => item['id'].toString()).toList();
      final payload = pending.map(_toBackendPayload).toList();

      await _apiService.logInteractionBatch(payload);
      await _localDataService.markBackendInteractionsSynced(ids);

      return ids.length;
    } catch (_) {
      try {
        final pending = await _localDataService.getPendingBackendInteractions(
          limit: limit,
        );
        final ids = pending.map((item) => item['id'].toString()).toList();
        await _localDataService.markBackendInteractionSyncAttempted(ids);
      } catch (_) {
        // Sync runs in the background, so queue bookkeeping is best-effort.
      }
      return 0;
    } finally {
      _syncing = false;
    }
  }

  Map<String, dynamic> _toBackendPayload(Map<String, dynamic> item) {
    return {
      'user_id': item['user_id']?.toString() ?? '',
      'destination_id': item['destination_id']?.toString() ?? '',
      'event_type': item['event_type']?.toString() ?? '',
      'value': (item['value'] as num?)?.toDouble() ?? 1.0,
      'timestamp': item['timestamp']?.toString(),
    };
  }
}
