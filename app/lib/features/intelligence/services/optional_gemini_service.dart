import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/intelligence/core/intelligence_config.dart';

/// Optional online enhancement through the FastAPI backend only.
///
/// The mobile app must never call Groq, Gemini, Anthropic, or any other
/// server-side AI provider directly because API keys in an APK are extractable.
class OptionalGeminiService {
  final IntelligenceConfig config;
  const OptionalGeminiService({this.config = IntelligenceConfig.production});

  Future<String?> enhance({
    required String userMessage,
    required String localAnswer,
    required bool isEmergency,
    required double localConfidence,
  }) async {
    if (isEmergency) return null;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork = connectivity.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return null;

      final response = await http
          .post(
            BackendConfig.uri('/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': userMessage,
              'language': 'en',
              'top_k': 5,
              'history': [
                if (localAnswer.trim().isNotEmpty)
                  {'role': 'assistant', 'text': localAnswer.trim()},
              ],
            }),
          )
          .timeout(config.onlineTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['offline'] == true ||
          decoded['fallback']?.toString() == 'rule_based') {
        return null;
      }

      final answer = (decoded['answer'] ?? decoded['reply'])?.toString().trim();
      if (answer == null || answer.isEmpty) return null;
      return answer;
    } catch (_) {
      return null;
    }
  }
}
