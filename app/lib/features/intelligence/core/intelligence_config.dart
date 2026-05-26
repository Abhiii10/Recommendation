class IntelligenceConfig {
  final int retrievalTopK;
  final double semanticWeight;
  final double lexicalWeight;
  final double highConfidenceThreshold;
  final double mediumConfidenceThreshold;
  final Duration onlineTimeout;
  final int conversationMemoryTurns;
  final bool enableOnlineEnhancement;
  final bool enableNeuralTranslation;

  const IntelligenceConfig({
    this.retrievalTopK = 5,
    this.semanticWeight = 0.60,
    this.lexicalWeight = 0.40,
    this.highConfidenceThreshold = 0.80,
    this.mediumConfidenceThreshold = 0.60,
    this.onlineTimeout = const Duration(seconds: 5),
    this.conversationMemoryTurns = 10,
    this.enableOnlineEnhancement = true,
    this.enableNeuralTranslation = true,
  });

  static const production = IntelligenceConfig();

  IntelligenceConfig copyWith({
    int? retrievalTopK,
    double? semanticWeight,
    double? lexicalWeight,
    double? highConfidenceThreshold,
    double? mediumConfidenceThreshold,
    Duration? onlineTimeout,
    int? conversationMemoryTurns,
    bool? enableOnlineEnhancement,
    bool? enableNeuralTranslation,
  }) {
    return IntelligenceConfig(
      retrievalTopK: retrievalTopK ?? this.retrievalTopK,
      semanticWeight: semanticWeight ?? this.semanticWeight,
      lexicalWeight: lexicalWeight ?? this.lexicalWeight,
      highConfidenceThreshold:
          highConfidenceThreshold ?? this.highConfidenceThreshold,
      mediumConfidenceThreshold:
          mediumConfidenceThreshold ?? this.mediumConfidenceThreshold,
      onlineTimeout: onlineTimeout ?? this.onlineTimeout,
      conversationMemoryTurns:
          conversationMemoryTurns ?? this.conversationMemoryTurns,
      enableOnlineEnhancement:
          enableOnlineEnhancement ?? this.enableOnlineEnhancement,
      enableNeuralTranslation:
          enableNeuralTranslation ?? this.enableNeuralTranslation,
    );
  }
}
