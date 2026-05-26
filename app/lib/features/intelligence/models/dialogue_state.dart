import 'conversation_turn.dart';
import 'dialogue_slot.dart';

class DialogueState {
  final String conversationId;
  final String? currentIntent;
  final Map<String, DialogueSlot> slots;
  final List<ConversationTurn> history;
  final List<String> pendingQuestions;
  final Map<String, dynamic> preferences;

  const DialogueState({
    required this.conversationId,
    this.currentIntent,
    this.slots = const {},
    this.history = const [],
    this.pendingQuestions = const [],
    this.preferences = const {},
  });

  factory DialogueState.initial(String conversationId) =>
      DialogueState(conversationId: conversationId);

  DialogueState copyWith({
    String? currentIntent,
    Map<String, DialogueSlot>? slots,
    List<ConversationTurn>? history,
    List<String>? pendingQuestions,
    Map<String, dynamic>? preferences,
  }) {
    return DialogueState(
      conversationId: conversationId,
      currentIntent: currentIntent ?? this.currentIntent,
      slots: slots ?? this.slots,
      history: history ?? this.history,
      pendingQuestions: pendingQuestions ?? this.pendingQuestions,
      preferences: preferences ?? this.preferences,
    );
  }

  DialogueSlot? slot(String name) => slots[name];
}
