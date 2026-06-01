import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/core/utils/backend_config.dart';

class LlmChatApiService {
  final List<Map<String, String>> _history = [];

  final Duration timeout;
  final Duration healthTimeout;

  LlmChatApiService({
    this.timeout = const Duration(seconds: 30),
    this.healthTimeout = const Duration(seconds: 5),
  });

  Uri _uri(String path) {
    final base = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;
    return Uri.parse('$base$path');
  }

  Future<String> ask(String question) => chat(question);

  Future<String> chat(String question) async {
    final recentHistory = _history.length <= 6
        ? List<Map<String, String>>.from(_history)
        : _history.sublist(_history.length - 6);

    final url = _uri('/chat');
    debugPrint('🔵 Chat POST → $url');
    debugPrint('🔵 Chat question → $question');

    try {
      final response = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'language': 'en',
              'top_k': 5,
              'history': recentHistory,
            }),
          )
          .timeout(timeout);

      debugPrint('🔵 Chat response status → ${response.statusCode}');
      debugPrint(
          '🔵 Chat response body → ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'LLM chat failed: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answer = (data['answer'] ?? data['reply'])?.toString().trim();

      if (answer == null || answer.isEmpty) {
        throw Exception('LLM chat failed: empty answer');
      }

      _history.add({'role': 'user', 'text': question});
      _history.add({'role': 'model', 'text': answer});

      debugPrint(
          '✅ Chat success → ${answer.substring(0, answer.length.clamp(0, 100))}');
      return answer;
    } catch (e, stack) {
      debugPrint('🔴 Chat POST failed → $e');
      debugPrint('🔴 Stack → $stack');
      rethrow;
    }
  }

  void clearHistory() => _history.clear();

  Future<bool> isHealthy() async {
    final result = await BackendConfig.checkBackendHealth(
      timeout: healthTimeout,
    );
    if (!result.reachable) {
      debugPrint('Chat backend offline -> ${result.userMessage}');
    }
    return result.reachable;
  }
}
