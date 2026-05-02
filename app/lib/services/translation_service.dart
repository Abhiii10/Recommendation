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

  static const String _myMemoryBaseUrl = 'https://api.mymemory.translated.net';
  static const Duration _onlineTimeout = Duration(seconds: 8);
  static const double _phraseThreshold = 0.58;
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

    final phraseResult = _tryPhrasebook(trimmed, effectiveMode);

    if (phraseResult != null && phraseResult.confidence >= _phraseThreshold) {
      await _addToHistory(trimmed, phraseResult, effectiveMode);
      return phraseResult;
    }

    final intentResult = _tryIntentModel(trimmed, effectiveMode);

    if (intentResult != null) {
      await _addToHistory(trimmed, intentResult, effectiveMode);
      return intentResult;
    }

    if (allowOnline) {
      final onlineResult = await _tryOnline(trimmed, effectiveMode);

      if (onlineResult != null) {
        await _addToHistory(trimmed, onlineResult, effectiveMode);
        return onlineResult;
      }
    }

    return TranslationResult(
      translatedText: '',
      strategy: TranslationStrategy.noResult,
      confidence: 0.0,
      errorMessage: allowOnline
          ? 'No reliable translation found. Try a shorter tourism-related phrase, or check your internet connection for online translation.'
          : 'No offline match found. Try a simpler phrase about food, water, hotels, transport, directions, shopping, or emergencies.',
    );
  }

  List<PhrasebookEntry> entriesByCategory(String category) {
    return _phrasebook.where((entry) => entry.category == category).toList();
  }

  List<PhrasebookEntry> get allEntries => List.unmodifiable(_phrasebook);

  List<TranslationHistoryEntry> get history =>
      List.unmodifiable(_history.reversed.toList());

  Future<void> clearHistory() async {
    _history.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> _loadPhrasebook() async {
    final raw = await rootBundle.loadString('assets/data/phrasebook.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = decoded['entries'] as List? ?? [];

    _phrasebook = entries
        .whereType<Map>()
        .map((item) => PhrasebookEntry.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((entry) =>
            entry.id.isNotEmpty &&
            entry.english.isNotEmpty &&
            entry.nepali.isNotEmpty)
        .toList();
  }

  TranslationResult? _tryPhrasebook(String input, TranslationMode mode) {
    final scored = _phrasebook
        .map((entry) => _PhrasebookScore(
              entry: entry,
              score: _scoreEntry(input, entry, mode),
            ))
        .toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty || scored.first.score <= 0.0) return null;

    final best = scored.first;

    final translatedText = mode == TranslationMode.nepaliToEnglish
        ? best.entry.english
        : best.entry.nepali;

    return TranslationResult(
      translatedText: translatedText,
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
      final englishNorm = RomanNepaliNormalizer.normalize(entry.english);

      if (entry.english.toLowerCase().trim() == inputLower) return 1.0;
      if (englishNorm == inputNorm) return 0.98;

      final englishTokens = RomanNepaliNormalizer.tokenize(englishNorm).toSet();

      return _tokenScore(inputTokens, englishTokens) * 0.90;
    }

    if (inputIsDev) {
      final nepaliNorm = RomanNepaliNormalizer.normalize(entry.nepali);

      if (nepaliNorm == inputNorm) return 1.0;

      if (inputNorm.length >= 4 &&
          (nepaliNorm.contains(inputNorm) || inputNorm.contains(nepaliNorm))) {
        return 0.85;
      }

      return 0.0;
    }

    for (final alias in entry.romanized) {
      final aliasNorm = RomanNepaliNormalizer.normalize(alias);

      if (aliasNorm == inputNorm) return 0.98;
    }

    var best = 0.0;

    for (final alias in entry.romanized) {
      final aliasTokens = RomanNepaliNormalizer.tokenize(alias).toSet();
      final score = _tokenScore(inputTokens, aliasTokens);

      best = math.max(best, score);
    }

    return best * 0.90;
  }

  double _tokenScore(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final intersection = a.intersection(b).length;

    if (intersection == 0) return 0.0;

    final union = a.union(b).length;
    final jaccard = intersection / union;
    final coverage = intersection / math.min(a.length, b.length);

    return (jaccard * 0.45) + (coverage * 0.55);
  }

  TranslationResult? _tryIntentModel(String input, TranslationMode mode) {
    final result = TranslationIntentModel.instance.classify(input);

    if (result == null) return null;

    return TranslationResult(
      translatedText: result.outputForMode(mode),
      strategy: TranslationStrategy.intentModel,
      confidence: result.confidence,
      intent: result.intentId,
    );
  }

  Future<TranslationResult?> _tryOnline(
    String input,
    TranslationMode mode,
  ) async {
    try {
      final uri = Uri.parse('$_myMemoryBaseUrl/get').replace(
        queryParameters: {
          'q': input,
          'langpair': '${mode.sourceLang}|${mode.targetLang}',
          'de': 'rural-tourism-nepal@example.com',
        },
      );

      final response = await http.get(uri).timeout(_onlineTimeout);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final responseData = decoded['responseData'] as Map?;
      final translated = responseData?['translatedText']?.toString().trim();

      if (translated == null || translated.isEmpty) return null;

      final inputNorm = RomanNepaliNormalizer.normalize(input);
      final outputNorm = RomanNepaliNormalizer.normalize(translated);

      if (inputNorm == outputNorm) return null;

      final matchRaw = responseData?['match'];
      final confidence = matchRaw is num ? matchRaw.toDouble() : 0.70;

      return TranslationResult(
        translatedText: translated,
        strategy: TranslationStrategy.onlineFallback,
        confidence: confidence.clamp(0.0, 1.0),
      );
    } catch (_) {
      return null;
    }
  }

  TranslationMode _resolveMode(String input, TranslationMode requested) {
    if (requested != TranslationMode.autoDetect) return requested;

    final script = RomanNepaliNormalizer.detectScript(input);

    if (script == 'devanagari' || script == 'roman_nepali') {
      return TranslationMode.nepaliToEnglish;
    }

    return TranslationMode.englishToNepali;
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
    String input,
    TranslationResult result,
    TranslationMode mode,
  ) async {
    if (!result.isSuccess) return;

    final entry = TranslationHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputText: input,
      outputText: result.translatedText,
      mode: mode,
      strategy: result.strategy,
      timestamp: DateTime.now(),
    );

    _history.add(entry);

    if (_history.length > _maxHistoryEntries) {
      _history.removeRange(0, _history.length - _maxHistoryEntries);
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _historyKey,
      TranslationHistoryEntry.encodeList(_history),
    );
  }
}

class _PhrasebookScore {
  final PhrasebookEntry entry;
  final double score;

  const _PhrasebookScore({
    required this.entry,
    required this.score,
  });
}