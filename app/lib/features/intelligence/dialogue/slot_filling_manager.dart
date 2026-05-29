import 'package:rural_tourism_app/features/intelligence/models/dialogue_slot.dart';
import 'package:rural_tourism_app/features/intelligence/models/entity_mention.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';

class SlotFillingManager {
  final Map<String, List<String>> requiredSlotsByIntent;

  const SlotFillingManager({
    this.requiredSlotsByIntent = const {
      'destination_recommendation': ['activity_type'],
      'budget_relaxation': ['budget_level'],
      'homestay_search': ['location'],
    },
  });

  Map<String, DialogueSlot> extractSlots(NlpProcessingResult nlp) {
    final slots = <String, DialogueSlot>{};
    final text = TextUtils.normalizeSearchText(
      '${nlp.normalizedText} ${nlp.romanizedNormalizedText}',
    );

    String? enumMatch(Map<String, List<String>> patterns) {
      for (final entry in patterns.entries) {
        if (entry.value.any(text.contains)) return entry.key;
      }
      return null;
    }

    final budget = enumMatch(const {
      'low': ['cheap', 'budget', 'sasto', 'सस्तो', 'कम खर्च'],
      'medium': ['moderate', 'medium', 'mid range', 'मध्यम'],
      'high': ['luxury', 'premium', 'expensive', 'mahango', 'महँगो'],
    });
    if (budget != null) {
      slots['budget_level'] = DialogueSlot(
        name: 'budget_level',
        value: budget,
        confidence: 0.84,
        source: DialogueSlotSource.explicit,
      );
    }

    final activity = enumMatch(const {
      'relaxation': ['peaceful', 'quiet', 'relax', 'shanta', 'आराम', 'शान्त'],
      'adventure': ['trekking', 'hiking', 'rafting', 'paragliding', 'साहस'],
      'culture': [
        'culture',
        'village',
        'temple',
        'heritage',
        'संस्कृति',
        'गाउँ'
      ],
      'pilgrimage': ['religious', 'pilgrimage', 'sacred', 'mandir', 'मन्दिर'],
      'nature': ['nature', 'mountain', 'lake', 'forest', 'प्रकृति', 'ताल'],
      'family': ['family', 'kids', 'children', 'परिवार', 'बच्चा'],
    });
    if (activity != null) {
      slots['activity_type'] = DialogueSlot(
        name: 'activity_type',
        value: activity,
        confidence: 0.82,
        source: DialogueSlotSource.explicit,
      );
    }

    final durationEntity = nlp.entities
        .where((entity) => entity.type == EntityType.duration)
        .cast<EntityMention?>()
        .firstOrNull;
    if (durationEntity != null) {
      slots['duration'] = DialogueSlot(
        name: 'duration',
        value: durationEntity.text,
        confidence: durationEntity.confidence,
        source: DialogueSlotSource.explicit,
      );
    }

    final locationEntity = nlp.entities
        .where((entity) => entity.type == EntityType.destination)
        .cast<EntityMention?>()
        .firstOrNull;
    if (locationEntity != null) {
      slots['location'] = DialogueSlot(
        name: 'location',
        value: locationEntity.canonicalId ?? locationEntity.text,
        confidence: locationEntity.confidence,
        source: DialogueSlotSource.explicit,
      );
    }

    return slots;
  }

  List<String> missingRequiredSlots(
      String intent, Map<String, DialogueSlot> slots) {
    final required = requiredSlotsByIntent[intent] ?? const [];
    return required.where((slot) => !slots.containsKey(slot)).toList();
  }
}
