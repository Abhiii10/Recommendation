enum DialogueSlotSource {
  explicit,
  inferred,
  defaultValue,
}

class DialogueSlot {
  final String name;
  final Object? value;
  final double confidence;
  final DialogueSlotSource source;
  final DateTime updatedAt;

  DialogueSlot({
    required this.name,
    required this.value,
    required this.confidence,
    required this.source,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  DialogueSlot copyWith({
    Object? value,
    double? confidence,
    DialogueSlotSource? source,
  }) {
    return DialogueSlot(
      name: name,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }
}
