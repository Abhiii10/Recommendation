import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../translation/roman_nepali_normalizer.dart';
import '../translation/translation_intent_model.dart';
import '../translation/translation_models.dart';

export '../translation/translation_models.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const String _googleTranslateUrl =
      'https://translate.googleapis.com/translate_a/single';
  static const String _myMemoryBaseUrl =
      'https://api.mymemory.translated.net';
  static const Duration _onlineTimeout = Duration(seconds: 10);
  static const double _phraseThreshold = 0.46; // was 0.58 — too strict
  static const String _historyKey = 'translation_history_v3';
  static const int _maxHistoryEntries = 100;

  bool _isInitialized = false;
  List<PhrasebookEntry> _phrasebook = [];
  final List<TranslationHistoryEntry> _history = [];

  Future<void> initialize() async {
    if (_isInitialized) return;
    await Future.wait([
      _loadPhrasebook(),
      TranslationIntentModel.instance.initialize(),
      _loadHistory(),
    ]);
    _isInitialized = true;
  }

  Future<TranslationResult> translate({
    required String input,
    required TranslationMode mode,
    bool allowOnline = true,
  }) async {
    if (!_isInitialized) await initialize();

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const TranslationResult(
        translatedText: '',
        strategy: TranslationStrategy.noResult,
        confidence: 0.0,
        errorMessage: 'Empty input',
      );
    }

    final effectiveMode = _resolveMode(trimmed, mode);

    // 1. Phrasebook exact / fuzzy
    final phraseResult = _tryPhrasebook(trimmed, effectiveMode);
    if (phraseResult != null && phraseResult.confidence >= _phraseThreshold) {
      await _addToHistory(trimmed, phraseResult, effectiveMode);
      return phraseResult;
    }

    // 2. TF-IDF intent model
    final intentResult = _tryIntentModel(trimmed, effectiveMode);
    if (intentResult != null) {
      await _addToHistory(trimmed, intentResult, effectiveMode);
      return intentResult;
    }

    // 3. Online: Google Translate first (better Nepali quality)
    if (allowOnline) {
      final googleResult = await _tryGoogleTranslate(trimmed, effectiveMode);
      if (googleResult != null) {
        await _addToHistory(trimmed, googleResult, effectiveMode);
        return googleResult;
      }

      // 4. Online: MyMemory fallback
      final myMemoryResult = await _tryMyMemory(trimmed, effectiveMode);
      if (myMemoryResult != null) {
        await _addToHistory(trimmed, myMemoryResult, effectiveMode);
        return myMemoryResult;
      }
    }

    // 5. Return best offline match even if below threshold (better than nothing)
    if (phraseResult != null && phraseResult.confidence > 0.20) {
      await _addToHistory(trimmed, phraseResult, effectiveMode);
      return phraseResult;
    }

    return TranslationResult(
      translatedText: '',
      strategy: TranslationStrategy.noResult,
      confidence: 0.0,
      errorMessage: allowOnline
          ? 'No translation found. Check your internet connection or try a simpler phrase.'
          : 'No offline match. Try phrases about food, water, hotels, transport, directions, or emergencies.',
    );
  }

  // ── Phrasebook ──────────────────────────────────────────────────────────

  List<PhrasebookEntry> entriesByCategory(String category) =>
      _phrasebook.where((e) => e.category == category).toList();

  List<PhrasebookEntry> get allEntries => List.unmodifiable(_phrasebook);

  TranslationResult? _tryPhrasebook(String input, TranslationMode mode) {
    final scored = _phrasebook
        .map((e) => _Score(entry: e, score: _scoreEntry(input, e, mode)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty || scored.first.score <= 0.0) return null;
    final best = scored.first;
    final text = mode == TranslationMode.nepaliToEnglish
        ? best.entry.english
        : best.entry.nepali;
    return TranslationResult(
      translatedText: text,
      strategy: TranslationStrategy.phrasebookMatch,
      confidence: best.score.clamp(0.0, 1.0),
      matchedEntry: best.entry,
      intent: best.entry.id,
    );
  }

  double _scoreEntry(String input, PhrasebookEntry entry, TranslationMode mode) {
    final inputLower = input.toLowerCase().trim();
    final inputNorm = RomanNepaliNormalizer.normalize(input);
    final inputTokens = RomanNepaliNormalizer.tokenize(inputNorm).toSet();
    final inputIsDev = RomanNepaliNormalizer.isDevanagari(input);

    if (mode == TranslationMode.englishToNepali) {
      final engNorm = RomanNepaliNormalizer.normalize(entry.english);
      if (entry.english.toLowerCase().trim() == inputLower) return 1.0;
      if (engNorm == inputNorm) return 0.98;

      // Romanized exact then fuzzy
      for (final alias in entry.romanized) {
        if (alias.toLowerCase().trim() == inputLower) return 0.97;
        if (RomanNepaliNormalizer.normalize(alias) == inputNorm) return 0.95;
      }
      for (final alias in entry.romanized) {
        final an = RomanNepaliNormalizer.normalize(alias);
        if (inputNorm.contains(an) || an.contains(inputNorm)) {
          final ratio = math.min(inputNorm.length, an.length) /
              math.max(inputNorm.length, an.length);
          if (ratio > 0.65) return 0.80 * ratio;
        }
      }

      var bestRom = 0.0;
      for (final alias in entry.romanized) {
        final at = RomanNepaliNormalizer.tokenize(alias).toSet();
        final s = _tok(inputTokens, at);
        if (s > bestRom) bestRom = s;
      }
      if (bestRom > 0) return bestRom * 0.88;

      final engTokens = RomanNepaliNormalizer.tokenize(engNorm).toSet();
      return _tok(inputTokens, engTokens) * 0.85;
    }

    // Nepali → English
    if (inputIsDev) {
      final neNorm = RomanNepaliNormalizer.normalize(entry.nepali);
      if (neNorm == inputNorm) return 1.0;
      if (inputNorm.length >= 3 &&
          (neNorm.contains(inputNorm) || inputNorm.contains(neNorm))) {
        return 0.82;
      }
      return 0.0;
    }

    // Romanized Nepali input
    for (final alias in entry.romanized) {
      if (alias.toLowerCase().trim() == inputLower) return 0.97;
      if (RomanNepaliNormalizer.normalize(alias) == inputNorm) return 0.95;
    }
    var best = 0.0;
    for (final alias in entry.romanized) {
      final at = RomanNepaliNormalizer.tokenize(alias).toSet();
      final s = _tok(inputTokens, at);
      if (s > best) best = s;
    }
    return best * 0.88;
  }

  double _tok(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final inter = a.intersection(b).length;
    if (inter == 0) return 0.0;
    final union = a.union(b).length;
    return (inter / union) * 0.40 + (inter / math.min(a.length, b.length)) * 0.60;
  }

  // ── Intent model ────────────────────────────────────────────────────────

  TranslationResult? _tryIntentModel(String input, TranslationMode mode) {
    final r = TranslationIntentModel.instance.classify(input);
    if (r == null) return null;
    return TranslationResult(
      translatedText: r.outputForMode(mode),
      strategy: TranslationStrategy.intentModel,
      confidence: r.confidence,
      intent: r.intentId,
    );
  }

  // ── Google Translate (unofficial, free, no key) ─────────────────────────

  Future<TranslationResult?> _tryGoogleTranslate(
      String input, TranslationMode mode) async {
    try {
      final uri = Uri.parse(_googleTranslateUrl).replace(
        queryParameters: {
          'client': 'gtx',
          'sl': mode.sourceLang,
          'tl': mode.targetLang,
          'dt': 't',
          'q': input,
        },
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(_onlineTimeout);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final chunks = decoded[0];
      if (chunks is! List) return null;

      final buf = StringBuffer();
      for (final c in chunks) {
        if (c is List && c.isNotEmpty && c[0] is String) buf.write(c[0]);
      }

      final translated = buf.toString().trim();
      if (translated.isEmpty) return null;
      if (translated.toUpperCase() == input.toUpperCase()) return null;

      final ni = RomanNepaliNormalizer.normalize(input);
      final no = RomanNepaliNormalizer.normalize(translated);
      if (ni == no) return null;

      return TranslationResult(
        translatedText: translated,
        strategy: TranslationStrategy.onlineFallback,
        confidence: 0.90,
      );
    } catch (_) {
      return null;
    }
  }

  // ── MyMemory fallback ───────────────────────────────────────────────────

  Future<TranslationResult?> _tryMyMemory(
      String input, TranslationMode mode) async {
    try {
      final uri = Uri.parse('$_myMemoryBaseUrl/get').replace(
        queryParameters: {
          'q': input,
          'langpair': '${mode.sourceLang}|${mode.targetLang}',
        },
      );

      final response = await http.get(uri).timeout(_onlineTimeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rd = decoded['responseData'] as Map?;
      final translated = rd?['translatedText']?.toString().trim();

      if (translated == null || translated.isEmpty) return null;
      if (translated.startsWith('MYMEMORY WARNING')) return null;
      if (translated.toUpperCase() == input.toUpperCase()) return null;

      final ni = RomanNepaliNormalizer.normalize(input);
      final no = RomanNepaliNormalizer.normalize(translated);
      if (ni == no) return null;

      final matchRaw = rd?['match'];
      final confidence =
          matchRaw is num ? matchRaw.toDouble().clamp(0.0, 1.0) : 0.65;

      return TranslationResult(
        translatedText: translated,
        strategy: TranslationStrategy.onlineFallback,
        confidence: confidence,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Auto-detect ─────────────────────────────────────────────────────────

  TranslationMode _resolveMode(String input, TranslationMode requested) {
    if (requested != TranslationMode.autoDetect) return requested;
    final script = RomanNepaliNormalizer.detectScript(input);
    if (script == 'devanagari' || script == 'roman_nepali') {
      return TranslationMode.nepaliToEnglish;
    }
    return TranslationMode.englishToNepali;
  }

  // ── History ─────────────────────────────────────────────────────────────

  List<TranslationHistoryEntry> get history =>
      List.unmodifiable(_history.reversed.toList());

  Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _history
        ..clear()
        ..addAll(TranslationHistoryEntry.decodeList(raw));
    } catch (_) {}
  }

  Future<void> _addToHistory(
      String input, TranslationResult result, TranslationMode mode) async {
    if (!result.isSuccess) return;
    _history.add(TranslationHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputText: input,
      outputText: result.translatedText,
      mode: mode,
      strategy: result.strategy,
      timestamp: DateTime.now(),
    ));
    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(0, _history.length - _maxHistoryEntries);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _historyKey, TranslationHistoryEntry.encodeList(_history));
  }

  // ── Loader ──────────────────────────────────────────────────────────────

  Future<void> _loadPhrasebook() async {
    final raw = await rootBundle.loadString('assets/data/phrasebook.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = decoded['entries'] as List? ?? [];
    _phrasebook = entries
        .whereType<Map>()
        .map((e) => PhrasebookEntry.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty && e.english.isNotEmpty && e.nepali.isNotEmpty)
        .toList();
  }
}

class _Score {
  final PhrasebookEntry entry;
  final double score;
  const _Score({required this.entry, required this.score});
}