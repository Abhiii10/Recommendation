import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:rural_tourism_app/features/intelligence/core/intelligence_constants.dart';
import 'package:rural_tourism_app/features/intelligence/models/knowledge_entry.dart';

class KnowledgeRepository {
  final List<KnowledgeEntry> _entries = [];

  List<KnowledgeEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    if (_entries.isNotEmpty) return;
    await _loadEnhancedKnowledge();
    await _loadDestinationsAsKnowledge();
    await _loadAccommodationsAsKnowledge();
  }

  KnowledgeEntry? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  List<KnowledgeEntry> byIntent(String intent) =>
      _entries.where((entry) => entry.intent == intent).toList();

  void add(KnowledgeEntry entry) {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  bool delete(String id) {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.id == id);
    return _entries.length != before;
  }

  Future<void> _loadEnhancedKnowledge() async {
    try {
      final raw = await rootBundle.loadString(
        IntelligenceConstants.knowledgeBaseAsset,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entries = decoded['entries'] as List? ?? const [];
      _entries.addAll(
        entries
            .whereType<Map>()
            .map((item) =>
                KnowledgeEntry.fromJson(Map<String, dynamic>.from(item)))
            .where((entry) => entry.id.isNotEmpty),
      );
    } catch (_) {
      // The repository can still operate from existing app data.
    }
  }

  Future<void> _loadDestinationsAsKnowledge() async {
    try {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final decoded = jsonDecode(raw) as List;
      for (final item in decoded.whereType<Map>()) {
        final json = Map<String, dynamic>.from(item);
        final id = json['id']?.toString() ?? '';
        final name = json['name']?.toString() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final activities = _list(json['activities']);
        final seasons = _list(json['best_season']);
        final tags = _list(json['tags']);
        _entries.add(
          KnowledgeEntry(
            id: 'dest_$id',
            type: 'destination',
            category: _list(json['category']).join(', '),
            questionEn: 'Tell me about $name',
            answerEn:
                '$name is in ${json['district'] ?? json['province'] ?? 'Nepal'}. '
                '${json['full_description'] ?? json['short_description'] ?? ''} '
                'Activities: ${activities.join(', ')}. Best season: ${seasons.join(', ')}. '
                'Budget: ${json['budget_level'] ?? 'medium'}.',
            answerNe:
                '$name नेपालको ग्रामीण पर्यटन गन्तव्य हो। गतिविधि: ${activities.join(', ')}। उत्तम मौसम: ${seasons.join(', ')}।',
            keywords: [name, ...activities, ...seasons, ...tags],
            intent: 'destination_recommendation',
            relatedDestinations: [id],
            metadata: json,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadAccommodationsAsKnowledge() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/accommodations.json');
      final decoded = jsonDecode(raw) as List;
      for (final item in decoded.whereType<Map>()) {
        final json = Map<String, dynamic>.from(item);
        final id = json['id']?.toString() ?? '';
        final name = json['name']?.toString() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final destination = json['destination_name']?.toString() ?? 'this area';
        final amenities = _list(json['amenities']);
        _entries.add(
          KnowledgeEntry(
            id: 'acc_$id',
            type: 'accommodation',
            category: json['type']?.toString() ?? 'accommodation',
            questionEn: 'Where can I stay in $destination?',
            answerEn: '$name is a ${json['type'] ?? 'stay'} in $destination. '
                'Price range: ${json['price_range'] ?? 'unspecified'}. '
                'Amenities: ${amenities.join(', ')}. '
                'Phone: ${json['phone'] ?? 'confirm locally'}.',
            answerNe:
                '$destination मा $name उपलब्ध छ। मूल्य: ${json['price_range'] ?? 'नखुलेको'}। सुविधा: ${amenities.join(', ')}।',
            keywords: [
              name,
              destination,
              'homestay',
              'hotel',
              'room',
              ...amenities
            ],
            intent: 'homestay_search',
            relatedDestinations: [
              json['destination_id']?.toString() ?? destination
            ],
            metadata: json,
          ),
        );
      }
    } catch (_) {}
  }

  List<String> _list(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value == null) return const [];
    return value
        .toString()
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
