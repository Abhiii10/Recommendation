class ConversationTurn {
  final String userText;
  final String assistantText;
  final String intent;
  final double confidence;
  final DateTime timestamp;

  ConversationTurn({
    required this.userText,
    required this.assistantText,
    required this.intent,
    required this.confidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
