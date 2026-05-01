import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'roman_nepali_normalizer.dart';
import 'translation_models.dart';

class TranslationIntentModel {
  TranslationIntentModel._();

  static final TranslationIntentModel instance = TranslationIntentModel._();

  static const String _assetPath = 'assets/data/translation_intents.json';
  static const double threshold = 0.58;

  bool _initialized = false;
  List<TranslationIntent> _intents = [];
  List<_IntentDocument> _documents = [];
  Map<String, double> _idf = {};

  static const Set<String> _stopWords = {
    'i',
    'am',
    'is',
    'are',
    'the',
    'a',
    'an',
    'to',
    'of',
    'for',
    'in',
    'on',
    'at',
    'me',
    'my',
    'you',
    'your',
    'can',
    'could',
    'please',
    'do',
    'does',
    'did',
  };

  Future<void> initialize() async {
    if (_initialized) return;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    _intents = (decoded['intents'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TranslationIntent.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((intent) =>
            intent.id.isNotEmpty &&
            intent.outputEn.isNotEmpty &&
            intent.outputNe.isNotEmpty &&
            intent.patterns.isNotEmpty)
        .toList();

    _buildDocuments();
    _initialized = true;
  }

  IntentClassificationResult? classify(String input) {
    if (!_initialized || _documents.isEmpty) return null;

    final normalizedInput = RomanNepaliNormalizer.normalize(input);

    if (normalizedInput.isEmpty) return null;

    for (final doc in _documents) {
      if (doc.normalizedPattern == normalizedInput) {
        return IntentClassificationResult(
          intentId: doc.intent.id,
          category: doc.intent.category,
          outputEn: doc.intent.outputEn,
          outputNe: doc.intent.outputNe,
          matchedPattern: doc.rawPattern,
          confidence: 0.98,
          urgent: doc.intent.urgent,
        );
      }
    }

    final inputTokens = _tokenize(normalizedInput);

    if (inputTokens.length <= 1) return null;

    final inputVector = _vectorize(inputTokens);

    _IntentDocument? best;
    var bestScore = 0.0;

    for (final doc in _documents) {
      final cosine = _cosine(inputVector, doc.vector);
      final coverage = _coverage(inputTokens, doc.tokens);
      final score = ((cosine * 0.72) + (coverage * 0.28)).clamp(0.0, 1.0);

      if (score > bestScore) {
        bestScore = score;
        best = doc;
      }
    }

    if (best == null || bestScore < threshold) return null;

    return IntentClassificationResult(
      intentId: best.intent.id,
      category: best.intent.category,
      outputEn: best.intent.outputEn,
      outputNe: best.intent.outputNe,
      matchedPattern: best.rawPattern,
      confidence: bestScore,
      urgent: best.intent.urgent,
    );
  }

  List<TranslationIntent> get intents => List.unmodifiable(_intents);

  static List<String> intentToPhrasebookCategories(String intentId) {
    final id = intentId.toLowerCase();

    if (id.contains('water') ||
        id.contains('hungry') ||
        id.contains('food') ||
        id.contains('menu') ||
        id.contains('vegetarian')) {
      return ['food'];
    }

    if (id.contains('hotel') ||
        id.contains('homestay') ||
        id.contains('room') ||
        id.contains('wifi')) {
      return ['accommodation'];
    }

    if (id.contains('bus') ||
        id.contains('ticket') ||
        id.contains('distance') ||
        id.contains('time') ||
        id.contains('lost')) {
      return ['transport', 'directions'];
    }

    if (id.contains('doctor') ||
        id.contains('help') ||
        id.contains('police') ||
        id.contains('medicine')) {
      return ['emergency'];
    }

    if (id.contains('trail') ||
        id.contains('guide') ||
        id.contains('porter')) {
      return ['trekking'];
    }

    if (id.contains('photo') || id.contains('temple')) {
      return ['culture'];
    }

    if (id.contains('price') ||
        id.contains('discount') ||
        id.contains('market')) {
      return ['shopping'];
    }

    return [];
  }

  void _buildDocuments() {
    final rawDocs = <_RawIntentDocument>[];

    for (final intent in _intents) {
      for (final pattern in intent.patterns) {
        final normalized = RomanNepaliNormalizer.normalize(pattern);
        final tokens = _tokenize(normalized);

        if (normalized.isEmpty || tokens.isEmpty) continue;

        rawDocs.add(
          _RawIntentDocument(
            intent: intent,
            rawPattern: pattern,
            normalizedPattern: normalized,
            tokens: tokens,
          ),
        );
      }
    }

    final df = <String, int>{};

    for (final doc in rawDocs) {
      for (final token in doc.tokens.toSet()) {
        df[token] = (df[token] ?? 0) + 1;
      }
    }

    final n = rawDocs.length;

    _idf = {
      for (final entry in df.entries)
        entry.key: math.log((n + 1) / (entry.value + 1)) + 1.0
    };

    _documents = rawDocs
        .map(
          (doc) => _IntentDocument(
            intent: doc.intent,
            rawPattern: doc.rawPattern,
            normalizedPattern: doc.normalizedPattern,
            tokens: doc.tokens,
            vector: _vectorize(doc.tokens),
          ),
        )
        .toList();
  }

  List<String> _tokenize(String normalizedText) {
    return normalizedText
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .where((token) {
      if (RomanNepaliNormalizer.isDevanagari(token)) return true;
      if (_stopWords.contains(token)) return false;
      return token.length > 1;
    }).toList();
  }

  Map<String, double> _vectorize(List<String> tokens) {
    if (tokens.isEmpty) return {};

    final tf = <String, int>{};

    for (final token in tokens) {
      tf[token] = (tf[token] ?? 0) + 1;
    }

    return {
      for (final entry in tf.entries)
        entry.key: (entry.value / tokens.length) * (_idf[entry.key] ?? 1.0)
    };
  }

  double _cosine(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (final value in a.values) {
      normA += value * value;
    }

    for (final value in b.values) {
      normB += value * value;
    }

    for (final entry in a.entries) {
      dot += entry.value * (b[entry.key] ?? 0.0);
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  double _coverage(List<String> inputTokens, List<String> patternTokens) {
    if (inputTokens.isEmpty || patternTokens.isEmpty) return 0.0;

    var matched = 0;

    for (final token in inputTokens) {
      if (patternTokens.contains(token)) matched++;
    }

    return matched / math.min(inputTokens.length, patternTokens.length);
  }
}

class _RawIntentDocument {
  final TranslationIntent intent;
  final String rawPattern;
  final String normalizedPattern;
  final List<String> tokens;

  const _RawIntentDocument({
    required this.intent,
    required this.rawPattern,
    required this.normalizedPattern,
    required this.tokens,
  });
}

class _IntentDocument {
  final TranslationIntent intent;
  final String rawPattern;
  final String normalizedPattern;
  final List<String> tokens;
  final Map<String, double> vector;

  const _IntentDocument({
    required this.intent,
    required this.rawPattern,
    required this.normalizedPattern,
    required this.tokens,
    required this.vector,
  });
}