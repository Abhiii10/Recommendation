import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/translation/translation_engine.dart';

/// LLM-powered translation: tries Claude → Groq → Gemini in order.
/// Handles English↔Nepali including Roman Nepali input.
class NeuralTranslationAdapter implements TranslationEngine {
  bool _available = true; // Always available — checked at runtime

  bool get isAvailable => _available;

  @override
  Future<void> load() async {
    // Check if at least one API key is configured
    final hasKey = _env('ANTHROPIC_API_KEY').isNotEmpty ||
        _env('GROQ_API_KEY').isNotEmpty ||
        _env('GEMINI_API_KEY').isNotEmpty;
    _available = hasKey;
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    if (!request.allowNeural) return null;

    final targetLang = request.targetLanguage == 'ne'
        ? 'Nepali (Devanagari script — use proper Devanagari Unicode, NOT Roman Nepali)'
        : 'English';
    final sourceLang = request.targetLanguage == 'ne' ? 'English' : 'Nepali';

    final prompt = '''Translate the following $sourceLang text to $targetLang.
Tourism context: This is for a Nepal rural tourism app. Prefer natural, 
simple language a local guide or tourist would use.
Reply with ONLY the translated text. No explanations, quotes, or notes.

Text to translate: ${request.text}''';

    // Try Claude first (best quality)
    final claude = await _tryClaude(prompt);
    if (claude != null) {
      return TranslationResponse(
        translatedText: claude,
        method: TranslationMethod.online,
        confidence: 0.95,
        isOffline: false,
        sourceLabel: 'Claude AI',
      );
    }

    // Try Groq (fast, free)
    final groq = await _tryGroq(prompt, request.targetLanguage);
    if (groq != null) {
      return TranslationResponse(
        translatedText: groq,
        method: TranslationMethod.online,
        confidence: 0.90,
        isOffline: false,
        sourceLabel: 'Groq AI',
      );
    }

    // Try Gemini (Google)
    final gemini = await _tryGemini(prompt);
    if (gemini != null) {
      return TranslationResponse(
        translatedText: gemini,
        method: TranslationMethod.online,
        confidence: 0.88,
        isOffline: false,
        sourceLabel: 'Gemini AI',
      );
    }

    return null;
  }

  Future<String?> _tryClaude(String prompt) async {
    final apiKey = _env('ANTHROPIC_API_KEY');
    if (apiKey.isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': 200,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['content'] as List?)?.first['text']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryGroq(String prompt, String targetLang) async {
    final apiKey = _env('GROQ_API_KEY');
    if (apiKey.isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'max_tokens': 200,
              'temperature': 0.1,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a precise translator. Reply ONLY with the translation.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['choices']?[0]?['message']?['content']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryGemini(String prompt) async {
    final apiKey = _env('GEMINI_API_KEY');
    if (apiKey.isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 200},
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      return parts?.first['text']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  String _env(String key) {
    try {
      return dotenv.maybeGet(key) ?? '';
    } catch (_) {
      return '';
    }
  }
}
