import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/intelligence_config.dart';

class OptionalGeminiService {
  final IntelligenceConfig config;

  const OptionalGeminiService({this.config = IntelligenceConfig.production});

  Future<String?> enhance({
    required String userMessage,
    required String localAnswer,
    required bool isEmergency,
    required double localConfidence,
  }) async {
    if (isEmergency ||
        !config.enableOnlineEnhancement ||
        localConfidence >= config.mediumConfidenceThreshold) {
      return null;
    }
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY') ?? '';
    if (apiKey.isEmpty) return null;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.any((result) => result != ConnectivityResult.none)) {
        return null;
      }
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'You are a rural Nepal tourism assistant. Ground your answer in the local offline answer below. Keep it concise.\n\nQuestion: $userMessage\n\nOffline answer: $localAnswer',
                    }
                  ],
                }
              ],
              'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': 320,
              },
            }),
          )
          .timeout(config.onlineTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List? ?? const [];
      final content = candidates.isEmpty ? null : candidates.first['content'];
      final parts = content is Map ? content['parts'] as List? : null;
      if (parts == null || parts.isEmpty) return null;
      final text = parts.first['text']?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}
