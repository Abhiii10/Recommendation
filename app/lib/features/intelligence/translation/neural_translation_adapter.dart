import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rural_tourism_app/core/utils/backend_config.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/translation/translation_engine.dart';

/// Online translation through FastAPI only.
///
/// Provider keys stay in backend/.env. The APK should never contain direct
/// provider endpoints or API keys for Claude, Groq, Gemini, Google, or DeepL.
class NeuralTranslationAdapter implements TranslationEngine {
  bool _available = true;

  bool get isAvailable => _available;

  @override
  Future<void> load() async {
    _available = true;
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    if (!request.allowNeural && !request.allowOnline) return null;

    try {
      final response = await http
          .post(
            BackendConfig.uri('/translate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': request.text,
              'direction': request.direction.name,
              'context': 'rural tourism Nepal mobile app',
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final translated = (decoded['translated'] ??
              decoded['translatedText'] ??
              decoded['text'])
          ?.toString()
          .trim();
      if (translated == null || translated.isEmpty) return null;

      final rawConfidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.75;
      final confidence = rawConfidence.clamp(0.0, 0.95).toDouble();

      return TranslationResponse(
        translatedText: translated,
        method: TranslationMethod.online,
        confidence: confidence,
        isOffline: false,
        romanized: decoded['roman']?.toString(),
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        sourceLabel: decoded['source']?.toString().isNotEmpty == true
            ? 'Backend ${decoded['source']}'
            : 'Backend translation',
      );
    } catch (_) {
      return null;
    }
  }
}
