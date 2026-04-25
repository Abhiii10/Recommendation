import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/backend_config.dart';

class LlmChatApiService {
  final Duration timeout;

  const LlmChatApiService({
    this.timeout = const Duration(seconds: 45),
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
        'Gemini chat failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = data['answer']?.toString().trim();

    if (answer == null || answer.isEmpty) {
      throw Exception('Gemini returned empty answer');
    }

    return answer;
  }
}