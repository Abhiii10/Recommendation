import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:rural_tourism_app/features/intelligence/core/intelligence_config.dart';

/// Production LLM service — tries Claude first, falls back to Groq, then Gemini.
/// This is the PRIMARY response path, not a fallback.
class OptionalGeminiService {
  final IntelligenceConfig config;
  const OptionalGeminiService({this.config = IntelligenceConfig.production});

  // Called for EVERY message (not just low-confidence ones)
  Future<String?> enhance({
    required String userMessage,
    required String localAnswer,
    required bool isEmergency,
    required double localConfidence,
  }) async {
    if (isEmergency) return null; // Emergency uses hardcoded fast responses

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork = connectivity.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return null;
    } catch (_) {
      return null;
    }

    // Try Claude (Anthropic) first
    final claudeResult = await _tryClaude(userMessage, localAnswer);
    if (claudeResult != null) return claudeResult;

    // Try Groq second
    final groqResult = await _tryGroq(userMessage, localAnswer);
    if (groqResult != null) return groqResult;

    // Fall back to Gemini
    return _tryGemini(userMessage, localAnswer);
  }

  Future<String?> _tryClaude(String userMessage, String offlineHint) async {
    final apiKey = _env('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001', // Fast + cheap
              'max_tokens': 400,
              'system': _systemPrompt,
              'messages': [
                {
                  'role': 'user',
                  'content': offlineHint.isNotEmpty
                      ? '$userMessage\n\n[Offline context: $offlineHint]'
                      : userMessage,
                }
              ],
            }),
          )
          .timeout(config.onlineTimeout);

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List?;
      if (content == null || content.isEmpty) return null;
      return content.first['text']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryGroq(String userMessage, String offlineHint) async {
    final apiKey = _env('GROQ_API_KEY');
    if (apiKey.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'max_tokens': 400,
              'temperature': 0.3,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {
                  'role': 'user',
                  'content': offlineHint.isNotEmpty
                      ? '$userMessage\n\n[Offline context: $offlineHint]'
                      : userMessage,
                },
              ],
            }),
          )
          .timeout(config.onlineTimeout);

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['choices']?[0]?['message']?['content']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryGemini(String userMessage, String offlineHint) async {
    final apiKey = _env('GEMINI_API_KEY');
    if (apiKey.isEmpty) return null;

    try {
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
                      'text': offlineHint.isNotEmpty
                          ? '$_systemPrompt\n\nUser: $userMessage\nOffline hint: $offlineHint'
                          : '$_systemPrompt\n\nUser: $userMessage',
                    }
                  ]
                }
              ],
              'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 400},
            }),
          )
          .timeout(config.onlineTimeout);

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List? ?? const [];
      if (candidates.isEmpty) return null;
      final parts = candidates.first['content']?['parts'] as List?;
      return parts?.first['text']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  static const _systemPrompt = '''
You are a friendly tourism assistant for rural Nepal. Help tourists with:
- Destinations: Pokhara, Chitwan, Bandipur, Ghandruk, Mustang, Ilam, etc.
- Food: dal bhat, momos, sel roti, where to eat, local cuisine
- Homestays and accommodation options
- Trekking routes and difficulty levels
- Transport: buses, jeeps, walking distances
- Culture: festivals, etiquette, dress codes
- Safety: emergency numbers (Police: 100, Ambulance: 102, Tourist Police: 01-4247041)
- Budget: typical costs in NPR
- Best seasons: spring (Mar-May) and autumn (Oct-Nov) are best

Keep answers concise (3-5 sentences max), practical, and friendly.
If unsure of exact details, say so and suggest confirming locally.
Respond in the same language as the user's question.
''';

  String _env(String key) {
    try {
      return dotenv.maybeGet(key) ?? '';
    } catch (_) {
      return '';
    }
  }
}
