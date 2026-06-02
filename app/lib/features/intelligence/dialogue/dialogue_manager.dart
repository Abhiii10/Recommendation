import 'package:rural_tourism_app/features/intelligence/models/conversation_turn.dart';
import 'package:rural_tourism_app/features/intelligence/models/dialogue_state.dart';
import 'package:rural_tourism_app/features/intelligence/models/intent_classification_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/nlp_processing_result.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/clarification_generator.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/conversation_memory.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/dialogue_state_tracker.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/slot_filling_manager.dart';

class DialogueManager {
  static const double _lastResortClarificationConfidence = 0.28;

  final ConversationMemory memory;
  final SlotFillingManager slotFillingManager;
  final ClarificationGenerator clarificationGenerator;
  final DialogueStateTracker stateTracker;

  const DialogueManager({
    required this.memory,
    required this.slotFillingManager,
    required this.clarificationGenerator,
    required this.stateTracker,
  });

  DialogueDecision updateBeforeResponse({
    required String conversationId,
    required NlpProcessingResult nlp,
    required IntentClassificationResult intent,
  }) {
    final state = memory.stateFor(conversationId);
    final extracted = slotFillingManager.extractSlots(nlp);
    final mergedSlots = {...state.slots, ...extracted};
    final missing = slotFillingManager.missingRequiredSlots(
      intent.intent,
      mergedSlots,
    );
    final clarification = clarificationGenerator.generate(
      intent: intent.intent,
      missingSlots: missing,
      confidence: intent.confidence,
      language: nlp.language,
    );
    final shouldClarify = clarification != null &&
        intent.confidence < _lastResortClarificationConfidence;
    final updated = stateTracker.update(
      state: state,
      intent: intent.intent,
      newSlots: extracted,
      pendingQuestions: shouldClarify ? [clarification] : const [],
    );
    memory.save(updated);
    return DialogueDecision(
      state: updated,
      shouldClarify: shouldClarify,
      clarificationQuestion: clarification,
      missingSlots: missing,
    );
  }

  void completeTurn({
    required String conversationId,
    required String userText,
    required String assistantText,
    required String intent,
    required double confidence,
  }) {
    final state = memory.stateFor(conversationId);
    memory.save(
      stateTracker.update(
        state: state,
        intent: intent,
        newSlots: const {},
        completedTurn: ConversationTurn(
          userText: userText,
          assistantText: assistantText,
          intent: intent,
          confidence: confidence,
        ),
      ),
    );
  }
}

class DialogueDecision {
  final DialogueState state;
  final bool shouldClarify;
  final String? clarificationQuestion;
  final List<String> missingSlots;

  const DialogueDecision({
    required this.state,
    required this.shouldClarify,
    this.clarificationQuestion,
    this.missingSlots = const [],
  });
}
