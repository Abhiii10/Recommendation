import 'package:rural_tourism_app/features/intelligence/models/conversation_turn.dart';
import 'package:rural_tourism_app/features/intelligence/models/dialogue_slot.dart';
import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';

class DialogueStateTracker {
  const DialogueStateTracker();

  DialogueState update({
    required DialogueState state,
    required String intent,
    required Map<String, DialogueSlot> newSlots,
    ConversationTurn? completedTurn,
    List<String> pendingQuestions = const [],
  }) {
    final history = [
      if (completedTurn != null) completedTurn,
      ...state.history,
    ].take(10).toList(growable: false);
    return state.copyWith(
      currentIntent: intent,
      slots: {...state.slots, ...newSlots},
      history: history,
      pendingQuestions: pendingQuestions,
      preferences: {
        ...state.preferences,
        for (final entry in newSlots.entries) entry.key: entry.value.value,
      },
    );
  }
}
