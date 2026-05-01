import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationSource { phrasebook, online, error }

class TranslationResult {
  final String text;
  final TranslationSource source;
  final String originalText;
  final bool englishToNepali;
  final String? matchedPhrase;

  const TranslationResult({
    required this.text,
    required this.source,
    required this.originalText,
    required this.englishToNepali,
    this.matchedPhrase,
  });

  bool get isOffline => source == TranslationSource.phrasebook;
  bool get isError => source == TranslationSource.error;

  String get sourceLabel {
    switch (source) {
      case TranslationSource.phrasebook:
        return 'Offline phrasebook';
      case TranslationSource.online:
        return 'Online translator';
      case TranslationSource.error:
        return 'Unavailable';
    }
  }
}

class TranslationHistoryEntry {
  final String sourceText;
  final String translatedText;
  final bool englishToNepali;
  final DateTime timestamp;
  final TranslationSource source;

  const TranslationHistoryEntry({
    required this.sourceText,
    required this.translatedText,
    required this.englishToNepali,
    required this.timestamp,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'src': sourceText,
        'tgt': translatedText,
        'dir': englishToNepali,
        'ts': timestamp.toIso8601String(),
        'source': source.index,
      };

  factory TranslationHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawSource = json['source'];
    final sourceIndex = rawSource is int ? rawSource : 0;
    final safeSourceIndex = sourceIndex >= 0 &&
            sourceIndex < TranslationSource.values.length
        ? sourceIndex
        : 0;

    return TranslationHistoryEntry(
      sourceText: json['src']?.toString() ?? '',
      translatedText: json['tgt']?.toString() ?? '',
      englishToNepali: json['dir'] == true,
      timestamp: DateTime.tryParse(json['ts']?.toString() ?? '') ??
          DateTime.now(),
      source: TranslationSource.values[safeSourceIndex],
    );
  }
}

class TranslationService {
  TranslationService._();

  static const String _myMemoryUrl = 'https://api.mymemory.translated.net/get';
  static const String _historyKey = 'translation_history_v3';
  static const int _maxHistory = 100;

  static Map<String, dynamic>? _phrasebook;

  /// Translates Nepali-English text using an honest fallback chain:
  /// 1. Offline tourism phrasebook (built into the app).
  /// 2. MyMemory online API for free-form text when internet is available.
  ///
  /// Do not replace this with google_mlkit_translation for Nepali: ML Kit's
  /// on-device translation language list does not include Nepali.
  static Future<TranslationResult> translate({
    required String text,
    required bool englishToNepali,
  }) async {
    final input = text.trim();
    if (input.isEmpty) {
      return TranslationResult(
        text: '',
        source: TranslationSource.error,
        originalText: '',
        englishToNepali: englishToNepali,
      );
    }

    final offline = await _phrasebookLookup(input, englishToNepali);
    if (offline != null) {
      await _saveHistory(offline);
      return offline;
    }

    try {
      final online = await _myMemory(input, englishToNepali);
      if (online != null) {
        await _saveHistory(online);
        return online;
      }
    } catch (_) {
      // Network errors are handled by the explicit error result below.
    }

    return TranslationResult(
      text: englishToNepali
          ? 'Translation unavailable. This phrase is not in the offline phrasebook. Connect to the internet for free-form translation.'
          : 'अनुवाद उपलब्ध छैन। यो वाक्य अफलाइन phrasebook मा छैन। स्वतन्त्र अनुवादका लागि इन्टरनेट जडान गर्नुहोस्।',
      source: TranslationSource.error,
      originalText: input,
      englishToNepali: englishToNepali,
    );
  }

  static Future<TranslationResult?> _phrasebookLookup(
    String input,
    bool englishToNepali,
  ) async {
    await _loadPhrasebook();
    final direction = englishToNepali ? 'en_to_ne' : 'ne_to_en';
    final categories =
        Map<String, dynamic>.from((_phrasebook?[direction] as Map?) ?? {});
    final normalizedInput = _normalize(input);

    for (final category in categories.values) {
      final phrases = Map<String, dynamic>.from(category as Map);
      for (final entry in phrases.entries) {
        if (_normalize(entry.key.toString()) == normalizedInput) {
          return _phraseResult(
            key: entry.key.toString(),
            value: entry.value.toString(),
            original: input,
            englishToNepali: englishToNepali,
          );
        }
      }
    }

    // Controlled fuzzy match: useful for tourist phrases such as
    // "please show me on the map" matching "Can you show me on the map?".
    for (final category in categories.values) {
      final phrases = Map<String, dynamic>.from(category as Map);
      for (final entry in phrases.entries) {
        final key = _normalize(entry.key.toString());
        if (normalizedInput.contains(key) || key.contains(normalizedInput)) {
          return _phraseResult(
            key: entry.key.toString(),
            value: entry.value.toString(),
            original: input,
            englishToNepali: englishToNepali,
          );
        }
      }
    }

    return null;
  }

  static TranslationResult _phraseResult({
    required String key,
    required String value,
    required String original,
    required bool englishToNepali,
  }) {
    return TranslationResult(
      text: value,
      source: TranslationSource.phrasebook,
      originalText: original,
      englishToNepali: englishToNepali,
      matchedPhrase: key,
    );
  }

  static Future<TranslationResult?> _myMemory(
    String text,
    bool englishToNepali,
  ) async {
    final uri = Uri.parse(_myMemoryUrl).replace(
      queryParameters: {
        'q': text,
        'langpair': englishToNepali ? 'en|ne' : 'ne|en',
        'de': 'rural.tourism.nepal@example.com',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final translated = (data['responseData'] as Map?)?['translatedText']
        ?.toString()
        .trim();

    if (translated == null || translated.isEmpty) return null;
    if (_normalize(translated) == _normalize(text)) return null;

    return TranslationResult(
      text: translated,
      source: TranslationSource.online,
      originalText: text,
      englishToNepali: englishToNepali,
    );
  }

  static Future<Map<String, Map<String, String>>> getPhrases({
    required bool englishToNepali,
  }) async {
    await _loadPhrasebook();
    final direction = englishToNepali ? 'en_to_ne' : 'ne_to_en';
    final raw = (_phrasebook?[direction] as Map?) ?? {};

    return {
      for (final category in raw.entries)
        category.key.toString(): Map<String, dynamic>.from(category.value as Map)
            .map((key, value) => MapEntry(key.toString(), value.toString()))
    };
  }

  static Future<void> _saveHistory(TranslationResult result) async {
    if (result.isError || result.text.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      raw.insert(
        0,
        jsonEncode(
          TranslationHistoryEntry(
            sourceText: result.originalText,
            translatedText: result.text,
            englishToNepali: result.englishToNepali,
            timestamp: DateTime.now(),
            source: result.source,
          ).toJson(),
        ),
      );
      if (raw.length > _maxHistory) {
        raw.removeRange(_maxHistory, raw.length);
      }
      await prefs.setStringList(_historyKey, raw);
    } catch (_) {}
  }

  static Future<List<TranslationHistoryEntry>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      return raw
          .map((item) => TranslationHistoryEntry.fromJson(
                jsonDecode(item) as Map<String, dynamic>,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<void> _loadPhrasebook() async {
    if (_phrasebook != null) return;
    final raw = await rootBundle.loadString('assets/data/phrasebook.json');
    _phrasebook = jsonDecode(raw) as Map<String, dynamic>;
  }

  static bool containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}