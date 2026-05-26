class KnowledgeEntry {
  final String id;
  final String type;
  final String category;
  final String? questionEn;
  final String? questionNe;
  final String answerEn;
  final String answerNe;
  final List<String> keywords;
  final String intent;
  final List<String> relatedDestinations;
  final double confidenceWeight;
  final Map<String, dynamic> metadata;

  const KnowledgeEntry({
    required this.id,
    required this.type,
    required this.category,
    this.questionEn,
    this.questionNe,
    required this.answerEn,
    required this.answerNe,
    required this.keywords,
    required this.intent,
    this.relatedDestinations = const [],
    this.confidenceWeight = 1.0,
    this.metadata = const {},
  });

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    List<String> listOf(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value == null) return const [];
      return value
          .toString()
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return KnowledgeEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'faq',
      category: json['category']?.toString() ?? 'general',
      questionEn: json['question_en']?.toString(),
      questionNe: json['question_ne']?.toString(),
      answerEn: json['answer_en']?.toString() ?? '',
      answerNe: json['answer_ne']?.toString() ?? '',
      keywords: listOf(json['keywords']),
      intent: json['intent']?.toString() ?? 'fallback',
      relatedDestinations: listOf(json['related_destinations']),
      confidenceWeight: (json['confidence_weight'] as num?)?.toDouble() ?? 1.0,
      metadata:
          Map<String, dynamic>.from((json['metadata'] as Map?) ?? const {}),
    );
  }

  String textForLanguage(String languageCode) =>
      languageCode == 'ne' && answerNe.isNotEmpty ? answerNe : answerEn;

  String get searchableText => [
        questionEn,
        questionNe,
        answerEn,
        answerNe,
        keywords.join(' '),
        category,
        intent,
        relatedDestinations.join(' '),
      ].whereType<String>().join(' ');
}
