import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/backend_config.dart';

class LlmChatApiService {
  final Duration timeout;
  final Duration healthTimeout;

  const LlmChatApiService({
    this.timeout = const Duration(seconds: 15),
    this.healthTimeout = const Duration(seconds: 3),
  });

  Uri _uri(String path) {
    final normalizedBaseUrl = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;

    return Uri.parse('$normalizedBaseUrl$path');
  }

  Future<String> ask(String question) async {
    final response = await http
        .post(
          _uri('/chat'),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'question': question,
            'language': 'en',
            'top_k': 5,
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'LLM chat failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = data['answer']?.toString().trim();

    if (answer == null || answer.isEmpty) {
      throw Exception('LLM chat failed: empty answer');
    }

    return answer;
  }

  Future<bool> isHealthy() async {
    try {
      final response = await http.get(_uri('/health')).timeout(healthTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
