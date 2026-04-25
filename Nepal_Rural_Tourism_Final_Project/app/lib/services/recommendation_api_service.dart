import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/accommodation_model.dart';
import '../models/api_recommendation_item.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class RecommendationApiService {
  final String baseUrl;
  final Duration timeout;

  RecommendationApiService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
  });

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
      };

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
    final response = await http
        .post(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http
        .get(
          _uri(path),
          headers: _headers,
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
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

    return results
        .map(
          (value) =>
              ApiRecommendationItem.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> logInteraction({
    required String userId,
    required String destinationId,
    required String eventType,
    double value = 1.0,
  }) async {
    await _post('/interactions', {
      'user_id': userId,
      'destination_id': destinationId,
      'event_type': eventType,
      'value': value,
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
    final data = await _get('/health');
    return data['status'] == 'healthy';
  }
}