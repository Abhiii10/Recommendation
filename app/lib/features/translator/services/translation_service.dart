import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/backend_config.dart';
import 'language_detector.dart';
import 'roman_nepali_converter.dart';

enum TranslationDirection {
  autoDetect,
  englishToNepali,
  nepaliToEnglish,
}

enum TranslationSource {
  phrasebook,
  online,
  fallback,
}

class TranslationResult {
  final String translatedText;
  final String detectedSourceLang;
  final double confidence;
  final TranslationSource source;
  final bool isOffline;
  final String? romanized;
  final String? matchedEnglish;
  final String? matchedCategory;
  final String? warningMessage;

  const TranslationResult({
    required this.translatedText,
    required this.detectedSourceLang,
    required this.confidence,
    required this.source,
    required this.isOffline,
    this.romanized,
    this.matchedEnglish,
    this.matchedCategory,
    this.warningMessage,
  });
}

class TourismPhrasebookEntry {
  final String id;
  final String english;
  final String nepali;
  final String romanNepali;
  final List<String> aliases;
  final String category;
  final String context;
  final bool urgent;

  const TourismPhrasebookEntry({
    required this.id,
    required this.english,
    required this.nepali,
    required this.romanNepali,
    required this.aliases,
    required this.category,
    required this.context,
    this.urgent = false,
  });

  factory TourismPhrasebookEntry.fromJson(Map<String, dynamic> json) {
    final romanNepali = json['romanNepali']?.toString().trim();
    final romanized = (json['romanized'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return TourismPhrasebookEntry(
      id: json['id']?.toString() ?? '',
      english: json['english']?.toString().trim() ?? '',
      nepali: json['nepali']?.toString().trim() ?? '',
      romanNepali: (romanNepali != null && romanNepali.isNotEmpty)
          ? romanNepali
          : (romanized.isEmpty ? '' : romanized.first),
      aliases: romanized,
      category: _normalizeCategory(json['category']?.toString() ?? 'general'),
      context: json['context']?.toString() ?? 'tourism',
      urgent: json['urgent'] == true,
    );
  }

  static String _normalizeCategory(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'homestay') return 'accommodation';
    if (normalized == 'health') return 'emergency';
    if (normalized == 'price' || normalized == 'time') return 'shopping';
    if (normalized == 'greeting') return 'greetings';
    return normalized;
  }
}

class TranslationService {
  static const _failureMessage =
      'Translation unavailable offline. Please check your connection.';
  static const _onlineTimeout = Duration(seconds: 10);
  static const _myMemoryDailyLimit = 5000;
  static const _myMemoryWarningLimit = 4500;
  static const _myMemoryCounterPrefix = 'mymemory_words_';

  final http.Client _client;
  final RomanNepaliDetector _romanDetector;
  final RomanNepaliConverter _romanConverter;

  late final LanguageDetector _languageDetector;
  bool _initialized = false;
  List<TourismPhrasebookEntry> _phrasebook = [];

  TranslationService({
    http.Client? client,
    RomanNepaliDetector? romanDetector,
    RomanNepaliConverter? romanConverter,
  })  : _client = client ?? http.Client(),
        _romanDetector = romanDetector ?? RomanNepaliDetector(),
        _romanConverter = romanConverter ?? const RomanNepaliConverter() {
    _languageDetector = LanguageDetector(romanNepaliDetector: _romanDetector);
  }

  List<TourismPhrasebookEntry> get phrasebookEntries =>
      List.unmodifiable(_phrasebook);

  Future<void> initialize() async {
    if (_initialized) return;
    await Future.wait([
      _romanDetector.load(),
      _loadPhrasebook(),
    ]);
    _initialized = true;
  }

  // Translation priority chain:
  // exact phrasebook -> fuzzy phrasebook -> Roman Nepali conversion
  // -> MyMemory (>0.6) -> backend Claude fallback -> graceful failure
  Future<TranslationResult> translateText(
    String text,
    TranslationDirection direction,
  ) async {
    if (!_initialized) await initialize();

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _failure(
        detectedSourceLang: 'unknown',
        message: 'Enter text to translate.',
      );
    }

    final detected = _languageDetector.detect(trimmed);
    final pair = _resolvePair(detected, direction);

    final exact = _matchPhrasebook(trimmed, pair, exactOnly: true);
    if (exact != null) return exact;

    final fuzzy = _matchPhrasebook(trimmed, pair);
    if (fuzzy != null && fuzzy.confidence > 0.80) return fuzzy;

    if (detected.isRomanNepali) {
      final devanagari = _romanConverter.convert(trimmed);
      final romanMatch = _matchPhrasebook(
        devanagari,
        pair,
        romanDetected: true,
      );
      if (romanMatch != null && romanMatch.confidence > 0.80) {
        return romanMatch;
      }
    }

    final onlineInput =
        detected.isRomanNepali ? _romanConverter.convert(trimmed) : trimmed;
    final online = await _tryMyMemory(
      onlineInput,
      pair,
      romanDetected: detected.isRomanNepali,
    );
    if (online != null && online.confidence > 0.60) return online;

    final backend = await _tryClaudeBackend(
      trimmed,
      direction,
      pair,
      romanDetected: detected.isRomanNepali,
    );
    if (backend != null) return backend;

    return _failure(
      detectedSourceLang: pair.sourceLang,
      warningMessage: online?.warningMessage,
    );
  }

  _LanguagePair _resolvePair(
    LanguageDetectionResult detected,
    TranslationDirection direction,
  ) {
    final detectedSource = detected.languageCode;
    final detectedTarget = detectedSource == 'ne-NP' ? 'en-US' : 'ne-NP';

    switch (direction) {
      case TranslationDirection.autoDetect:
        return _LanguagePair(detectedSource, detectedTarget);
      case TranslationDirection.englishToNepali:
        if (detectedSource == 'ne-NP') {
          return const _LanguagePair('ne-NP', 'en-US');
        }
        return const _LanguagePair('en-US', 'ne-NP');
      case TranslationDirection.nepaliToEnglish:
        if (detectedSource == 'en-US') {
          return const _LanguagePair('en-US', 'ne-NP');
        }
        return const _LanguagePair('ne-NP', 'en-US');
    }
  }

  TranslationResult? _matchPhrasebook(
    String input,
    _LanguagePair pair, {
    bool exactOnly = false,
    bool romanDetected = false,
  }) {
    final scored = _phrasebook
        .map(
          (entry) => _PhraseScore(
            entry,
            _scoreEntry(input, entry, pair),
          ),
        )
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) return null;
    final best = scored.first;
    final exact = best.score >= 0.999;
    if (exactOnly && !exact) return null;
    if (!exactOnly && best.score <= 0.80) return null;

    return TranslationResult(
      translatedText: _outputFor(best.entry, pair),
      detectedSourceLang: pair.sourceLang,
      confidence: _displayConfidence(
        best.score,
        exactPhrasebook: exact,
        romanDetected: romanDetected && !exact,
      ),
      source: TranslationSource.phrasebook,
      isOffline: true,
      romanized: pair.targetLang == 'ne-NP' ? best.entry.romanNepali : null,
      matchedEnglish: best.entry.english,
      matchedCategory: best.entry.category,
    );
  }

  double _scoreEntry(
    String input,
    TourismPhrasebookEntry entry,
    _LanguagePair pair,
  ) {
    final inputNorm = _normalize(input);
    final candidates = pair.sourceLang == 'en-US'
        ? [entry.english]
        : [entry.nepali, entry.romanNepali, ...entry.aliases];

    var best = 0.0;
    for (final candidate in candidates) {
      final candidateNorm = _normalize(candidate);
      if (candidateNorm.isEmpty) continue;
      if (inputNorm == candidateNorm) return 1.0;
      best = math.max(best, _similarity(inputNorm, candidateNorm));
    }
    return best;
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    final aTokens = a.split(' ').where((item) => item.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((item) => item.isNotEmpty).toSet();
    var tokenScore = 0.0;
    if (aTokens.isNotEmpty && bTokens.isNotEmpty) {
      final intersection = aTokens.intersection(bTokens).length;
      final union = aTokens.union(bTokens).length;
      tokenScore = (intersection / union) * 0.40 +
          (intersection / math.min(aTokens.length, bTokens.length)) * 0.60;
    }

    final distance = _levenshtein(a, b);
    final charScore = 1 - (distance / math.max(a.length, b.length));
    return math.max(tokenScore, charScore.clamp(0.0, 1.0));
  }

  Future<TranslationResult?> _tryMyMemory(
    String input,
    _LanguagePair pair, {
    required bool romanDetected,
  }) async {
    final quota = await _reserveMyMemoryWords(input);
    if (!quota.allowed) {
      return TranslationResult(
        translatedText: _failureMessage,
        detectedSourceLang: pair.sourceLang,
        confidence: 0,
        source: TranslationSource.fallback,
        isOffline: false,
        warningMessage: quota.warning,
      );
    }

    try {
      final uri = Uri.https(
        'api.mymemory.translated.net',
        '/get',
        {
          'q': input,
          'langpair': '${pair.sourceLang}|${pair.targetLang}',
        },
      );
      final response = await _client.get(uri).timeout(_onlineTimeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['responseData'] as Map<String, dynamic>?;
      final translated = data?['translatedText']?.toString().trim() ?? '';
      if (translated.isEmpty ||
          translated.startsWith('MYMEMORY WARNING') ||
          _normalize(translated) == _normalize(input)) {
        return null;
      }

      final confidence = _parseMatch(data?['match']);
      return TranslationResult(
        translatedText: translated,
        detectedSourceLang: pair.sourceLang,
        confidence: _displayConfidence(
          confidence,
          romanDetected: romanDetected,
        ),
        source: TranslationSource.online,
        isOffline: false,
        warningMessage: quota.warning,
      );
    } catch (_) {
      return null;
    }
  }

  Future<TranslationResult?> _tryClaudeBackend(
    String input,
    TranslationDirection direction,
    _LanguagePair pair, {
    required bool romanDetected,
  }) async {
    try {
      final response = await _client
          .post(
            BackendConfig.uri('/translate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': input,
              'direction': direction.name,
              'context': 'tourism',
            }),
          )
          .timeout(_onlineTimeout);

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = decoded['translated']?.toString().trim() ?? '';
      if (translated.isEmpty) return null;

      return TranslationResult(
        translatedText: translated,
        detectedSourceLang: pair.sourceLang,
        confidence: _displayConfidence(
          _parseMatch(decoded['confidence']),
          romanDetected: romanDetected,
        ),
        source: TranslationSource.fallback,
        isOffline: false,
        romanized: decoded['roman']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_QuotaReservation> _reserveMyMemoryWords(String input) async {
    final count = input
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .length;
    final dayKey = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$_myMemoryCounterPrefix$dayKey';
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(key) ?? 0;
    final next = used + count;

    if (next > _myMemoryDailyLimit) {
      return const _QuotaReservation(
        allowed: false,
        warning: 'MyMemory daily free limit reached. Try again tomorrow.',
      );
    }

    await prefs.setInt(key, next);
    if (next >= _myMemoryWarningLimit) {
      return _QuotaReservation(
        allowed: true,
        warning:
            'MyMemory free limit is almost used today ($next/$_myMemoryDailyLimit words).',
      );
    }

    return const _QuotaReservation(allowed: true);
  }

  double _parseMatch(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) {
      return (double.tryParse(value) ?? 0.0).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  double _displayConfidence(
    double confidence, {
    bool exactPhrasebook = false,
    bool romanDetected = false,
  }) {
    if (exactPhrasebook) return 1.0;
    var value = confidence.clamp(0.0, 1.0);
    if (romanDetected) value = math.min(value, 0.75);
    return math.min(value, 0.95);
  }

  String _outputFor(TourismPhrasebookEntry entry, _LanguagePair pair) {
    return pair.targetLang == 'ne-NP' ? entry.nepali : entry.english;
  }

  TranslationResult _failure({
    required String detectedSourceLang,
    String message = _failureMessage,
    String? warningMessage,
  }) {
    return TranslationResult(
      translatedText: message,
      detectedSourceLang: detectedSourceLang,
      confidence: 0,
      source: TranslationSource.fallback,
      isOffline: false,
      warningMessage: warningMessage,
    );
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('।', ' ')
        .replaceAll(RegExp(r'[^\u0900-\u097Fa-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .join(' ');
  }

  int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        current[j + 1] = math.min(insert, math.min(delete, replace));
      }
      previous.setAll(0, current);
    }

    return previous[b.length];
  }

  Future<void> _loadPhrasebook() async {
    final loaded = <TourismPhrasebookEntry>[];
    await _loadPhrasebookAsset(
      'assets/data/intelligence/phrasebook_enhanced.json',
      loaded,
    );
    await _loadPhrasebookAsset('assets/data/phrasebook.json', loaded);

    final byEnglish = <String, TourismPhrasebookEntry>{};
    for (final entry in loaded) {
      if (entry.english.isEmpty || entry.nepali.isEmpty) continue;
      byEnglish.putIfAbsent(_normalize(entry.english), () => entry);
    }
    _phrasebook = byEnglish.values.toList(growable: false);
  }

  Future<void> _loadPhrasebookAsset(
    String path,
    List<TourismPhrasebookEntry> target,
  ) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entries = decoded['entries'] as List? ?? const [];
      target.addAll(
        entries.whereType<Map>().map(
              (item) => TourismPhrasebookEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
      );
    } catch (_) {}
  }
}

class _LanguagePair {
  final String sourceLang;
  final String targetLang;

  const _LanguagePair(this.sourceLang, this.targetLang);
}

class _PhraseScore {
  final TourismPhrasebookEntry entry;
  final double score;

  const _PhraseScore(this.entry, this.score);
}

class _QuotaReservation {
  final bool allowed;
  final String? warning;

  const _QuotaReservation({
    required this.allowed,
    this.warning,
  });
}
