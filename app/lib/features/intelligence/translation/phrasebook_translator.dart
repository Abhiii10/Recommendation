import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:rural_tourism_app/features/intelligence/core/intelligence_constants.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';
import 'package:rural_tourism_app/features/intelligence/translation/translation_engine.dart';

class PhrasebookTranslator implements TranslationEngine {
  final List<PhrasebookTranslationEntry> _entries = [];

  List<PhrasebookTranslationEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<void> load() async {
    if (_entries.isNotEmpty) return;
    var loadedEnhanced = false;
    try {
      final raw = await rootBundle.loadString(
        IntelligenceConstants.phrasebookAsset,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['entries'] as List? ?? const [];
      _entries.addAll(
        items.whereType<Map>().map(
              (item) => PhrasebookTranslationEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
      );
      loadedEnhanced = true;
    } catch (_) {
      loadedEnhanced = false;
    }
    await _loadLegacyPhrasebook();
    if (!loadedEnhanced && _entries.isEmpty) {
      throw StateError('No phrasebook entries available');
    }
  }

  Future<void> _loadLegacyPhrasebook() async {
    try {
      final raw = await rootBundle.loadString('assets/data/phrasebook.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['entries'] as List? ?? const [];
      final existingIds = _entries.map((entry) => entry.id).toSet();
      _entries.addAll(
        items.whereType<Map>().map(
          (item) {
            final entry = PhrasebookTranslationEntry.fromJson(
              Map<String, dynamic>.from(item),
            );
            return existingIds.contains(entry.id)
                ? PhrasebookTranslationEntry(
                    id: 'legacy_${entry.id}',
                    category: entry.category,
                    english: entry.english,
                    nepali: entry.nepali,
                    romanized: entry.romanized,
                    context: entry.context,
                    formality: entry.formality,
                  )
                : entry;
          },
        ),
      );
    } catch (_) {}
  }

  @override
  Future<TranslationResponse?> translate(TranslationRequest request) async {
    await load();
    final direction = _directionFor(request);
    final input = TextUtils.normalizeSearchText(request.text);
    if (input.isEmpty) return null;

    PhrasebookTranslationEntry? best;
    var bestScore = 0.0;
    var exact = false;
    for (final entry in _entries) {
      final candidates =
          direction == IntelligenceTranslationDirection.nepaliToEnglish
              ? [entry.nepali, ...entry.romanized]
              : [entry.english, ...entry.romanized];
      for (final candidate in candidates) {
        final score = _score(input, candidate);
        if (score > bestScore) {
          best = entry;
          bestScore = score;
          exact = TextUtils.normalizeSearchText(candidate) == input;
        }
      }
    }

    // FIX: lowered threshold from 0.45 → 0.38 so short valid phrases
    // like "thanks" or "sorry" are not incorrectly rejected
    if (best == null || bestScore < 0.38) return null;
    return TranslationResponse(
      translatedText:
          direction == IntelligenceTranslationDirection.nepaliToEnglish
              ? best.english
              : best.nepali,
      method: exact
          ? TranslationMethod.exactPhrasebook
          : TranslationMethod.fuzzyPhrasebook,
      // FIX: raised confidence cap from 0.88 → 0.93 so strong fuzzy matches
      // aren't unfairly penalised and don't unnecessarily fall through to online
      confidence: exact ? 1.0 : bestScore.clamp(0.0, 0.93),
      isOffline: true,
      alternatives: _alternatives(best, direction),
      romanized: best.romanized.isEmpty ? null : best.romanized.first,
      matchedId: best.id,
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

  IntelligenceTranslationDirection _directionFor(TranslationRequest request) {
    if (request.direction != IntelligenceTranslationDirection.auto) {
      return request.direction;
    }
    final hasDevanagari =
        request.text.codeUnits.any(TextUtils.isDevanagariCodeUnit);
    if (hasDevanagari) return IntelligenceTranslationDirection.nepaliToEnglish;
    final romanizedHits = _entries
        .expand((entry) => entry.romanized)
        .where((alias) => TextUtils.containsPhrase(request.text, alias))
        .length;
    return romanizedHits > 0
        ? IntelligenceTranslationDirection.nepaliToEnglish
        : IntelligenceTranslationDirection.englishToNepali;
  }

  double _score(String input, String candidate) {
    final normalized = TextUtils.normalizeSearchText(candidate);
    if (normalized == input) return 1.0;
    if (normalized.contains(input) || input.contains(normalized)) {
      final minLength =
          input.length < normalized.length ? input.length : normalized.length;
      final maxLength =
          input.length > normalized.length ? input.length : normalized.length;
      return 0.78 * minLength / maxLength;
    }
    final inputTokens = TextUtils.simpleTokens(input);
    final candidateTokens = TextUtils.simpleTokens(normalized);
    final jaccard = TextUtils.tokenJaccard(inputTokens, candidateTokens);
    final distance = TextUtils.levenshtein(input, normalized, maxDistance: 8);
    final editScore = 1 -
        (distance /
            (input.length > normalized.length
                ? input.length
                : normalized.length));
    return (jaccard * 0.72 + editScore.clamp(0.0, 1.0) * 0.28).clamp(0.0, 1.0);
  }

  List<String> _alternatives(
    PhrasebookTranslationEntry entry,
    IntelligenceTranslationDirection direction,
  ) {
    return direction == IntelligenceTranslationDirection.nepaliToEnglish
        ? [entry.nepali, ...entry.romanized]
        : [entry.english, ...entry.romanized];
  }
}

class PhrasebookTranslationEntry {
  final String id;
  final String category;
  final String english;
  final String nepali;
  final List<String> romanized;
  final String context;
  final String formality;

  const PhrasebookTranslationEntry({
    required this.id,
    required this.category,
    required this.english,
    required this.nepali,
    this.romanized = const [],
    this.context = '',
    this.formality = 'neutral',
  });

  factory PhrasebookTranslationEntry.fromJson(Map<String, dynamic> json) {
    return PhrasebookTranslationEntry(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      english: json['english']?.toString() ?? '',
      nepali: json['nepali']?.toString() ?? '',
      romanized: (json['romanized'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      context: json['context']?.toString() ?? '',
      formality: json['formality']?.toString() ?? 'neutral',
    );
  }
}