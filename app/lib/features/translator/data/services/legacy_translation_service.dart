import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/features/translator/data/services/translation_service.dart'
    as tourism;
import 'package:rural_tourism_app/features/translator/domain/models/translation_models.dart';

export 'package:rural_tourism_app/features/translator/domain/models/translation_models.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const String _historyKey = 'translation_history_v4';
  static const int _maxHistoryEntries = 100;

  final tourism.TranslationService _translator = tourism.TranslationService();
  final List<TranslationHistoryEntry> _history = [];

  bool _isInitialized = false;
  List<PhrasebookEntry> _phrasebook = [];

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _translator.initialize();
    _phrasebook = _translator.phrasebookEntries.map(_toLegacyEntry).toList();
    await _loadHistory();
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
        confidence: 0,
        errorMessage: 'Enter text to translate.',
      );
    }

    if (!allowOnline) {
      final offline = await _translator.translateText(
        trimmed,
        _toTourismDirection(mode),
        allowOnline: false,
      );
      final isOfflineResult =
          offline.source == tourism.TranslationSource.phrasebook ||
              offline.source == tourism.TranslationSource.template;
      if (!isOfflineResult) {
        return const TranslationResult(
          translatedText: '',
          strategy: TranslationStrategy.noResult,
          confidence: 0,
          errorMessage:
              'Translation unavailable offline. Please check your connection.',
        );
      }
      final legacyOffline = _toLegacyResult(offline);
      await _addToHistory(trimmed, legacyOffline, mode);
      return legacyOffline;
    }

    final result = await _translator.translateText(
      trimmed,
      _toTourismDirection(mode),
    );
    final legacy = _toLegacyResult(result);
    await _addToHistory(trimmed, legacy, mode);
    return legacy;
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

  TranslationResult _toLegacyResult(tourism.TranslationResult result) {
    if (result.source == tourism.TranslationSource.fallback &&
        result.confidence <= 0) {
      return TranslationResult(
        translatedText: '',
        strategy: TranslationStrategy.noResult,
        confidence: 0,
        errorMessage: result.translatedText,
        methodLabelOverride: 'No match',
        isOfflineOverride: false,
        warningMessage: result.warningMessage,
      );
    }

    final strategy = switch (result.source) {
      tourism.TranslationSource.phrasebook =>
        TranslationStrategy.phrasebookMatch,
      tourism.TranslationSource.template => TranslationStrategy.intentModel,
      tourism.TranslationSource.online => TranslationStrategy.onlineFallback,
      tourism.TranslationSource.fallback => TranslationStrategy.onlineFallback,
    };

    final methodLabel = switch (result.source) {
      tourism.TranslationSource.phrasebook => 'Offline phrasebook',
      tourism.TranslationSource.template => 'Offline template',
      tourism.TranslationSource.online => 'MyMemory ne-NP',
      tourism.TranslationSource.fallback => 'Claude fallback',
    };

    return TranslationResult(
      translatedText: result.translatedText,
      strategy: strategy,
      confidence: result.confidence,
      intent: result.matchedCategory,
      matchedEntry: _findLegacyMatch(result.matchedEnglish),
      methodLabelOverride: methodLabel,
      isOfflineOverride: result.isOffline,
      romanized: result.romanized,
      warningMessage: result.warningMessage,
    );
  }

  PhrasebookEntry? _findLegacyMatch(String? english) {
    if (english == null || english.isEmpty) return null;
    final normalized = english.toLowerCase().trim();
    for (final entry in _phrasebook) {
      if (entry.english.toLowerCase().trim() == normalized) return entry;
    }
    return null;
  }

  PhrasebookEntry _toLegacyEntry(tourism.TourismPhrasebookEntry entry) {
    return PhrasebookEntry(
      id: entry.id,
      category: entry.category,
      english: entry.english,
      nepali: entry.nepali,
      romanized: [
        if (entry.romanNepali.isNotEmpty) entry.romanNepali,
        ...entry.aliases,
      ],
      isUrgent: entry.urgent,
    );
  }

  tourism.TranslationDirection _toTourismDirection(TranslationMode mode) {
    return switch (mode) {
      TranslationMode.autoDetect => tourism.TranslationDirection.autoDetect,
      TranslationMode.englishToNepali =>
        tourism.TranslationDirection.englishToNepali,
      TranslationMode.nepaliToEnglish =>
        tourism.TranslationDirection.nepaliToEnglish,
    };
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
    _history.add(
      TranslationHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        inputText: input,
        outputText: result.translatedText,
        mode: mode,
        strategy: result.strategy,
        timestamp: DateTime.now(),
      ),
    );

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
