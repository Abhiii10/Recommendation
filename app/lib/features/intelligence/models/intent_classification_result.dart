class IntentClassificationResult {
  final String intent;
  final double confidence;
  final Map<String, double> alternatives;
  final List<String> matchedFeatures;
  final bool isEmergency;

  const IntentClassificationResult({
    required this.intent,
    required this.confidence,
    this.alternatives = const {},
    this.matchedFeatures = const [],
    this.isEmergency = false,
  });

  bool get isHighConfidence => confidence >= 0.80;
  bool get isMediumConfidence => confidence >= 0.60 && confidence < 0.80;
  bool get isLowConfidence => confidence < 0.60;

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'confidence': confidence,
        'alternatives': alternatives,
        'matched_features': matchedFeatures,
        'is_emergency': isEmergency,
      };
}
