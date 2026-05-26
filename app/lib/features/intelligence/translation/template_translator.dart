import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/intelligence_constants.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart';
import '../utils/text_utils.dart';
import 'translation_engine.dart';

class TemplateTranslator implements TranslationEngine {
  final List<TranslationTemplate> _templates = [];

  @override
  Future<void> load() async {
    if (_templates.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(
        IntelligenceConstants.translationTemplatesAsset,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['templates'] as List? ?? const [];
      _templates.addAll(
        items.whereType<Map>().map(
              (item) => TranslationTemplate.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
      );
    } catch (_) {}
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    await load();
    final direction =
        request.direction == IntelligenceTranslationDirection.nepaliToEnglish
            ? IntelligenceTranslationDirection.nepaliToEnglish
            : IntelligenceTranslationDirection.englishToNepali;
    for (final template in _templates) {
      final sourcePattern =
          direction == IntelligenceTranslationDirection.nepaliToEnglish
              ? template.patternNe
              : template.patternEn;
      final targetPattern =
          direction == IntelligenceTranslationDirection.nepaliToEnglish
              ? template.patternEn
              : template.patternNe;
      final slots = _match(sourcePattern, request.text, template.slots);
      if (slots == null) continue;
      var translated = targetPattern;
      for (final entry in slots.entries) {
        translated =
            translated.replaceAll('{${entry.key}}', entry.value.trim());
      }
      return TranslationResponse(
        translatedText: translated,
        method: TranslationMethod.template,
        confidence: 0.82,
        isOffline: true,
        matchedId: template.id,
        sourceLanguage:
            direction == IntelligenceTranslationDirection.nepaliToEnglish
                ? 'ne'
                : 'en',
        targetLanguage:
            direction == IntelligenceTranslationDirection.nepaliToEnglish
                ? 'en'
                : 'ne',
      );
    }
    return null;
  }

  Map<String, String>? _match(
      String pattern, String input, List<String> slots) {
    var regexPattern = RegExp.escape(_normalizePattern(pattern));
    for (final slot in slots) {
      regexPattern = regexPattern.replaceAll('\\{$slot\\}', '(.+?)');
    }
    final regex = RegExp('^$regexPattern\\??\$', caseSensitive: false);
    final match = regex.firstMatch(TextUtils.normalizeSearchText(input));
    if (match == null) return null;
    final values = <String, String>{};
    for (var i = 0; i < slots.length; i++) {
      values[slots[i]] = _restoreSlotText(input, match.group(i + 1) ?? '');
    }
    return values;
  }

  String _restoreSlotText(String input, String normalizedSlot) {
    final normalized = TextUtils.normalizeSearchText(normalizedSlot);
    if (normalized.isEmpty) return normalizedSlot;
    final words = input.split(RegExp(r'\s+'));
    for (final word in words) {
      if (TextUtils.normalizeSearchText(word) == normalized) return word;
    }
    return normalizedSlot;
  }

  String _normalizePattern(String pattern) {
    final normalized = pattern
        .toLowerCase()
        .replaceAll('\u0964', ' ')
        .replaceAll('\u0965', ' ')
        .replaceAll(
          RegExp(r'[!"#$%&()*+,./:;<=>?@\[\]^_`|~\r\n\t-]+'),
          ' ',
        );
    return TextUtils.compactWhitespace(normalized);
  }
}

class TranslationTemplate {
  final String id;
  final String patternEn;
  final String patternNe;
  final List<String> slots;

  const TranslationTemplate({
    required this.id,
    required this.patternEn,
    required this.patternNe,
    required this.slots,
  });

  factory TranslationTemplate.fromJson(Map<String, dynamic> json) {
    return TranslationTemplate(
      id: json['id']?.toString() ?? '',
      patternEn: json['pattern_en']?.toString() ?? '',
      patternNe: json['pattern_ne']?.toString() ?? '',
      slots: (json['slots'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
