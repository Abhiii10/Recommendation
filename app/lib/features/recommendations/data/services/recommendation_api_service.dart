import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/config/app_config.dart';
import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation_model.dart';
import 'package:rural_tourism_app/features/recommendations/domain/models/api_recommendation_item.dart';
import 'package:rural_tourism_app/features/auth/data/services/auth_session_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class RecommendationApiService {
  final String baseUrl;
  final Duration timeout;
  final Duration healthTimeout;

  RecommendationApiService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
    this.healthTimeout = AppConfig.backendHealthTimeout,
  });

  Future<Map<String, String>> _headers() async {
    final token = await AuthSessionService.instance.currentToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return Uri.parse('$normalizedBaseUrl$path');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _headers();
    final response = await _sendWithRetry(
      () => http.post(
        _uri(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Duration? requestTimeout,
  }) async {
    final headers = await _headers();
    final response = await _sendWithRetry(
      () => http.get(
        _uri(path),
        headers: headers,
      ),
      requestTimeout: requestTimeout,
    );

    return _decodeObject(response);
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() request, {
    Duration? requestTimeout,
  }) async {
    final effectiveTimeout = requestTimeout ?? timeout;
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await request().timeout(effectiveTimeout);

        if (response.statusCode >= 500 && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }

        return response;
      } on TimeoutException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    throw NetworkException('Backend request failed: $lastError');
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw ApiException(
      response.statusCode,
      'Expected a JSON object from backend.',
    );
  }

  Future<List<ApiRecommendationItem>> recommend({
    required String activity,
    required String budget,
    required String season,
    required String vibe,
    required bool familyFriendly,
    required int adventureLevel,
    String? userId,
    int topK = 10,
  }) async {
    final data = await _post('/recommend', {
      'activity': activity,
      'budget': budget,
      'season': season,
      'vibe': vibe,
      'family_friendly': familyFriendly,
      'adventure_level': adventureLevel,
      'user_id': userId,
      'top_k': topK,
    });

    final results = (data['results'] as List?) ?? const [];
    final responseMetadata = <String, String>{
      if (data['recommendation_id'] != null)
        'recommendation_id': data['recommendation_id'].toString(),
      if (data['pipeline_used'] != null)
        'pipeline_used': data['pipeline_used'].toString(),
      if (data['recommendation_id'] != null) 'server_logged_impression': 'true',
    };

    return results.map(
      (value) {
        final item =
            ApiRecommendationItem.fromJson(value as Map<String, dynamic>);
        if (responseMetadata.isEmpty) return item;
        return item.copyWith(
          metadata: {
            ...item.metadata,
            ...responseMetadata,
          },
        );
      },
    ).toList();
  }

  Future<void> logInteraction({
    required String userId,
    required String destinationId,
    required String eventType,
    double value = 1.0,
    DateTime? timestamp,
    String? recommendationId,
    List<String> recommendedDestinationIds = const [],
    String? pipelineUsed,
  }) async {
    await _post('/interactions', {
      'user_id': userId,
      'destination_id': destinationId,
      'event_type': eventType,
      'action': eventType,
      'value': value,
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      if (recommendationId != null) 'recommendation_id': recommendationId,
      if (recommendedDestinationIds.isNotEmpty)
        'recommended_destination_ids': recommendedDestinationIds,
      if (pipelineUsed != null) 'pipeline_used': pipelineUsed,
    });
  }

  Future<void> logInteractionBatch(
    List<Map<String, dynamic>> interactions,
  ) async {
    if (interactions.isEmpty) {
      return;
    }

    await _post('/interactions/batch', {
      'interactions': interactions,
    });
  }

  Future<List<ApiRecommendationItem>> similar({
    required String destinationId,
    int topK = 5,
  }) async {
    final data = await _get('/similar/$destinationId?top_k=$topK');
    final results = (data['results'] as List?) ?? const [];

    return results
        .map(
          (value) =>
              ApiRecommendationItem.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AccommodationModel>> accommodations(String destinationId) async {
    final data = await _get('/destinations/$destinationId/accommodations');
    final results = (data['results'] as List?) ?? const [];

    return results
        .map(
          (value) => AccommodationModel.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<bool> isHealthy() async {
    final result = await BackendConfig.checkBackendHealth(
      baseUrl: baseUrl,
      timeout: healthTimeout,
    );
    return result.reachable;
  }
}
