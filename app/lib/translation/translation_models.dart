import 'dart:convert';

enum TranslationMode {
  autoDetect,
  englishToNepali,
  nepaliToEnglish,
}

extension TranslationModeX on TranslationMode {
  String get label {
    switch (this) {
      case TranslationMode.autoDetect:
        return 'Auto';
      case TranslationMode.englishToNepali:
        return 'EN → NE';
      case TranslationMode.nepaliToEnglish:
        return 'NE → EN';
    }
  }

  String get sourceLang {
    switch (this) {
      case TranslationMode.nepaliToEnglish:
        return 'ne';
      case TranslationMode.autoDetect:
      case TranslationMode.englishToNepali:
        return 'en';
    }
  }

  String get targetLang {
    switch (this) {
      case TranslationMode.nepaliToEnglish:
        return 'en';
      case TranslationMode.autoDetect:
      case TranslationMode.englishToNepali:
        return 'ne';
    }
  }

  bool get outputsNepali => this == TranslationMode.englishToNepali;
}

enum TranslationStrategy {
  phrasebookMatch,
  intentModel,
  onlineFallback,
  noResult,
}

class PhrasebookEntry {
  final String id;
  final String category;
  final String english;
  final String nepali;
  final List<String> romanized;
  final bool isUrgent;

  const PhrasebookEntry({
    required this.id,
    required this.category,
    required this.english,
    required this.nepali,
    required this.romanized,
    this.isUrgent = false,
  });

  factory PhrasebookEntry.fromJson(Map<String, dynamic> json) {
    return PhrasebookEntry(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      english: json['english']?.toString() ?? '',
      nepali: json['nepali']?.toString() ?? '',
      romanized: (json['romanized'] as List? ?? [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      isUrgent: json['urgent'] == true,
    );
  }
}

class PhrasebookCategory {
  final String id;
  final String label;
  final String emoji;

  const PhrasebookCategory({
    required this.id,
    required this.label,
    required this.emoji,
  });

  static const List<PhrasebookCategory> all = [
    PhrasebookCategory(id: 'greetings', label: 'Greetings', emoji: '🙏'),
    PhrasebookCategory(id: 'food', label: 'Food', emoji: '🍛'),
    PhrasebookCategory(id: 'accommodation', label: 'Stay', emoji: '🏠'),
    PhrasebookCategory(id: 'transport', label: 'Transport', emoji: '🚌'),
    PhrasebookCategory(id: 'directions', label: 'Directions', emoji: '🧭'),
    PhrasebookCategory(id: 'trekking', label: 'Trekking', emoji: '🥾'),
    PhrasebookCategory(id: 'emergency', label: 'Emergency', emoji: '🚨'),
    PhrasebookCategory(id: 'shopping', label: 'Shopping', emoji: '🛍️'),
    PhrasebookCategory(id: 'culture', label: 'Culture', emoji: '🛕'),
  ];
}

class TranslationResult {
  final String translatedText;
  final TranslationStrategy strategy;
  final double confidence;
  final String? errorMessage;
  final String? intent;
  final PhrasebookEntry? matchedEntry;

  const TranslationResult({
    required this.translatedText,
    required this.strategy,
    required this.confidence,
    this.errorMessage,
    this.intent,
    this.matchedEntry,
  });

  bool get isSuccess =>
      translatedText.trim().isNotEmpty && strategy != TranslationStrategy.noResult;

  bool get isOffline =>
      strategy == TranslationStrategy.phrasebookMatch ||
      strategy == TranslationStrategy.intentModel;

  bool get isUrgent {
    if (matchedEntry?.isUrgent == true) return true;

    final value = intent?.toLowerCase() ?? '';
    return value.contains('emergency') ||
        value.contains('doctor') ||
        value.contains('police') ||
        value.contains('help') ||
        value.contains('medicine');
  }

  String get strategyLabel {
    switch (strategy) {
      case TranslationStrategy.phrasebookMatch:
        return 'Offline phrasebook';
      case TranslationStrategy.intentModel:
        return 'Offline model';
      case TranslationStrategy.onlineFallback:
        return 'Online';
      case TranslationStrategy.noResult:
        return 'No match';
    }
  }

  String get confidencePercent {
    final value = (confidence.clamp(0.0, 1.0) * 100).round();
    return '$value%';
  }
}

class TranslationHistoryEntry {
  final String id;
  final String inputText;
  final String outputText;
  final TranslationMode mode;
  final TranslationStrategy strategy;
  final DateTime timestamp;

  const TranslationHistoryEntry({
    required this.id,
    required this.inputText,
    required this.outputText,
    required this.mode,
    required this.strategy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'inputText': inputText,
        'outputText': outputText,
        'mode': mode.index,
        'strategy': strategy.index,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TranslationHistoryEntry.fromJson(Map<String, dynamic> json) {
    final modeIndex = json['mode'] is int ? json['mode'] as int : 0;
    final strategyIndex = json['strategy'] is int ? json['strategy'] as int : 0;

    return TranslationHistoryEntry(
      id: json['id']?.toString() ?? '',
      inputText: json['inputText']?.toString() ?? '',
      outputText: json['outputText']?.toString() ?? '',
      mode: modeIndex >= 0 && modeIndex < TranslationMode.values.length
          ? TranslationMode.values[modeIndex]
          : TranslationMode.autoDetect,
      strategy:
          strategyIndex >= 0 && strategyIndex < TranslationStrategy.values.length
              ? TranslationStrategy.values[strategyIndex]
              : TranslationStrategy.noResult,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static String encodeList(List<TranslationHistoryEntry> entries) {
    return jsonEncode(entries.map((entry) => entry.toJson()).toList());
  }

  static List<TranslationHistoryEntry> decodeList(String raw) {
    final decoded = jsonDecode(raw);

    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((item) => TranslationHistoryEntry.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }
}

class TranslationIntent {
  final String id;
  final String category;
  final String outputEn;
  final String outputNe;
  final List<String> patterns;
  final bool urgent;

  const TranslationIntent({
    required this.id,
    required this.category,
    required this.outputEn,
    required this.outputNe,
    required this.patterns,
    this.urgent = false,
  });

  factory TranslationIntent.fromJson(Map<String, dynamic> json) {
    return TranslationIntent(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      outputEn: json['output_en']?.toString() ?? '',
      outputNe: json['output_ne']?.toString() ?? '',
      patterns: (json['patterns'] as List? ?? [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      urgent: json['urgent'] == true,
    );
  }
}

class IntentClassificationResult {
  final String intentId;
  final String category;
  final String outputEn;
  final String outputNe;
  final String matchedPattern;
  final double confidence;
  final bool urgent;

  const IntentClassificationResult({
    required this.intentId,
    required this.category,
    required this.outputEn,
    required this.outputNe,
    required this.matchedPattern,
    required this.confidence,
    required this.urgent,
  });

  String outputForMode(TranslationMode mode) {
    if (mode == TranslationMode.nepaliToEnglish) return outputEn;
    return outputNe;
  }
}