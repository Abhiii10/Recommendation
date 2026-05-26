import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/intelligence_constants.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart';
import '../utils/text_utils.dart';
import 'translation_engine.dart';

class GlossaryTranslator implements TranslationEngine {
  final List<GlossaryTerm> _terms = [];

  List<GlossaryTerm> get terms => List.unmodifiable(_terms);

  @override
  Future<void> load() async {
    if (_terms.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(
        IntelligenceConstants.tourismGlossaryAsset,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['terms'] as List? ?? const [];
      _terms.addAll(
        items.whereType<Map>().map(
              (item) => GlossaryTerm.fromJson(Map<String, dynamic>.from(item)),
            ),
      );
    } catch (_) {}
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    await load();
    var output = request.text;
    var replacements = 0;
    final toEnglish =
        request.direction == IntelligenceTranslationDirection.nepaliToEnglish ||
            (request.direction == IntelligenceTranslationDirection.auto &&
                request.text.codeUnits.any(TextUtils.isDevanagariCodeUnit));

    for (final term in _terms) {
      final sourceTerms = toEnglish
          ? [term.nepali, ...term.romanized]
          : [term.english, ...term.romanized];
      for (final source in sourceTerms) {
        if (source.isEmpty) continue;
        final regex = RegExp(RegExp.escape(source), caseSensitive: false);
        if (regex.hasMatch(output)) {
          output =
              output.replaceAll(regex, toEnglish ? term.english : term.nepali);
          replacements++;
        }
      }
    }
    if (replacements == 0 || output == request.text) return null;
    return TranslationResponse(
      translatedText: output,
      method: TranslationMethod.glossary,
      confidence: (0.58 + replacements * 0.08).clamp(0.0, 0.82),
      isOffline: true,
      sourceLanguage: toEnglish ? 'ne' : 'en',
      targetLanguage: toEnglish ? 'en' : 'ne',
    );
  }
}

class GlossaryTerm {
  final String english;
  final String nepali;
  final List<String> romanized;
  final String category;

  const GlossaryTerm({
    required this.english,
    required this.nepali,
    this.romanized = const [],
    this.category = 'general',
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      english: json['english']?.toString() ?? '',
      nepali: json['nepali']?.toString() ?? '',
      romanized: (json['romanized'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      category: json['category']?.toString() ?? 'general',
    );
  }
}
