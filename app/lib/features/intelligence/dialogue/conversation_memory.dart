import '../core/intelligence_config.dart';
import '../models/conversation_turn.dart';
import '../models/dialogue_state.dart';

class ConversationMemory {
  final IntelligenceConfig config;
  final _states = <String, DialogueState>{};

  ConversationMemory({this.config = IntelligenceConfig.production});

  DialogueState stateFor(String conversationId) => _states.putIfAbsent(
      conversationId, () => DialogueState.initial(conversationId));

  void save(DialogueState state) {
    _states[state.conversationId] = state;
  }

  List<ConversationTurn> recentTurns(String conversationId) =>
      stateFor(conversationId)
          .history
          .take(config.conversationMemoryTurns)
          .toList();

  void clear(String conversationId) {
    _states.remove(conversationId);
  }
}
