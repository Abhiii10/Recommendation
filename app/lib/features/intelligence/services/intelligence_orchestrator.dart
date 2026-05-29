import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:rural_tourism_app/features/intelligence/core/intelligence_config.dart';
import 'package:rural_tourism_app/features/intelligence/core/intelligence_constants.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/clarification_generator.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/conversation_memory.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/dialogue_manager.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/dialogue_state_tracker.dart';
import 'package:rural_tourism_app/features/intelligence/dialogue/slot_filling_manager.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_encoder.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/embedding_index.dart';
import 'package:rural_tourism_app/features/intelligence/embeddings/semantic_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/intent/hybrid_intent_classifier.dart';
import 'package:rural_tourism_app/features/intelligence/intent/intent_training_data.dart';
import 'package:rural_tourism_app/features/intelligence/intent/semantic_intent_classifier.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/chatbot_response.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/advanced_tokenizer.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/devanagari_normalizer.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/language_detector.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/named_entity_recognizer.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/nepali_stemmer.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/nlp_pipeline.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/romanized_nepali_normalizer.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/stopword_remover.dart';
import 'package:rural_tourism_app/features/intelligence/nlp/synonym_expander.dart';
import 'package:rural_tourism_app/features/intelligence/rag/context_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/rag/rag_pipeline.dart';
import 'package:rural_tourism_app/features/intelligence/rag/response_generator.dart';
import 'package:rural_tourism_app/features/intelligence/rag/template_generator.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/bm25_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/hybrid_retriever.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/knowledge_repository.dart';
import 'package:rural_tourism_app/features/intelligence/retrieval/retrieval_reranker.dart';
import 'package:rural_tourism_app/features/intelligence/safety/emergency_detector.dart';
import 'package:rural_tourism_app/features/intelligence/safety/emergency_response_repository.dart';
import 'package:rural_tourism_app/features/intelligence/safety/safety_layer.dart';
import 'package:rural_tourism_app/features/intelligence/translation/glossary_translator.dart';
import 'package:rural_tourism_app/features/intelligence/translation/hybrid_translation_manager.dart';
import 'package:rural_tourism_app/features/intelligence/translation/neural_translation_adapter.dart';
import 'package:rural_tourism_app/features/intelligence/translation/phrasebook_translator.dart';
import 'package:rural_tourism_app/features/intelligence/translation/template_translator.dart';
import 'package:rural_tourism_app/features/intelligence/services/optional_gemini_service.dart';

class IntelligenceOrchestrator {
  final IntelligenceConfig config;

  bool _initialized = false;

  late final KnowledgeRepository knowledgeRepository;
  late final NlpPipeline nlpPipeline;
  late final HybridIntentClassifier intentClassifier;
  late final DialogueManager dialogueManager;
  late final RagPipeline ragPipeline;
  late final SafetyLayer safetyLayer;
  late final HybridTranslationManager translationManager;
  late final OptionalGeminiService optionalGeminiService;

  IntelligenceOrchestrator({this.config = IntelligenceConfig.production});

  Future<void> initialize() async {
    if (_initialized) return;

    final romanizedDictionary = await _loadStringMap(
      IntelligenceConstants.romanizedDictionaryAsset,
    );
    final stopwords = await _loadStringSet(
      IntelligenceConstants.nepaliStopwordsAsset,
      key: 'stopwords',
    );
    final ontology = await _loadOntology();
    final destinationGazetteer = await _loadDestinationGazetteer();
    final accommodationGazetteer = await _loadAccommodationGazetteer();

    knowledgeRepository = KnowledgeRepository();
    await knowledgeRepository.load();

    nlpPipeline = NlpPipeline(
      languageDetector: LanguageDetector(
        romanizedDictionary: romanizedDictionary.keys.toSet(),
      ),
      devanagariNormalizer: const DevanagariNormalizer(),
      romanizedNormalizer: RomanizedNepaliNormalizer(
        mappings: romanizedDictionary,
      ),
      tokenizer: const AdvancedTokenizer(),
      stemmer: NepaliStemmer(
        protectedTerms: destinationGazetteer.keys.toSet(),
      ),
      stopwordRemover: StopwordRemover(nepaliStopwords: stopwords),
      namedEntityRecognizer: NamedEntityRecognizer(
        destinationGazetteer: destinationGazetteer,
        accommodationGazetteer: accommodationGazetteer,
      ),
      synonymExpander: SynonymExpander(ontology: ontology),
    );

    final encoder = const EmbeddingEncoder();
    final embeddingIndex = EmbeddingIndex(encoder: encoder)
      ..build(knowledgeRepository.entries);
    final semanticRetriever = SemanticRetriever(
      encoder: encoder,
      index: embeddingIndex,
    );
    final bm25Retriever = BM25Retriever()..build(knowledgeRepository.entries);
    final hybridRetriever = HybridRetriever(
      semanticRetriever: semanticRetriever,
      bm25Retriever: bm25Retriever,
      config: config,
    );

    Future<IntentTrainingData> trainingLoader() => IntentTrainingData.load();
    final semanticIntent = SemanticIntentClassifier(
      encoder: encoder,
      trainingDataLoader: trainingLoader,
    );
    intentClassifier = HybridIntentClassifier(
      semanticClassifier: semanticIntent,
      trainingDataLoader: trainingLoader,
    );
    await intentClassifier.load();

    dialogueManager = DialogueManager(
      memory: ConversationMemory(config: config),
      slotFillingManager: const SlotFillingManager(),
      clarificationGenerator: const ClarificationGenerator(),
      stateTracker: const DialogueStateTracker(),
    );

    ragPipeline = RagPipeline(
      contextRetriever: ContextRetriever(
        hybridRetriever: hybridRetriever,
        reranker: const RetrievalReranker(),
      ),
      responseGenerator: const ResponseGenerator(
        templateGenerator: TemplateGenerator(),
      ),
    );

    safetyLayer = const SafetyLayer(
      detector: EmergencyDetector(),
      responseRepository: EmergencyResponseRepository(),
    );

    translationManager = HybridTranslationManager(
      phrasebookTranslator: PhrasebookTranslator(),
      templateTranslator: TemplateTranslator(),
      glossaryTranslator: GlossaryTranslator(),
      neuralTranslationAdapter: NeuralTranslationAdapter(),
    );
    await translationManager.load();
    optionalGeminiService = OptionalGeminiService(config: config);

    _initialized = true;
  }

  Future<ChatbotResponse> respond(ChatbotRequest request) async {
    await initialize();
    final nlp = nlpPipeline.process(request.text);

    final safety = safetyLayer.check(request.text, nlp.language);
    if (safety != null) return safety;

    final intent = intentClassifier.classify(nlp);
    final dialogue = dialogueManager.updateBeforeResponse(
      conversationId: request.conversationId,
      nlp: nlp,
      intent: intent,
    );

    final rag = ragPipeline.run(
      nlp: nlp,
      intent: intent.intent,
      dialogueState: dialogue.state,
    );
    var text = dialogue.shouldClarify && dialogue.clarificationQuestion != null
        ? dialogue.clarificationQuestion!
        : rag.text;
    var source = dialogue.shouldClarify
        ? ChatbotResponseSource.offlineModel
        : ChatbotResponseSource.offlineKnowledgeBase;
    final combinedConfidence =
        (intent.confidence * 0.45 + rag.confidence * 0.55).clamp(0.0, 1.0);

    if (request.allowOnlineEnhancement) {
      final enhanced = await optionalGeminiService.enhance(
        userMessage: request.text,
        localAnswer: text,
        isEmergency: false,
        localConfidence: combinedConfidence,
      );
      if (enhanced != null) {
        text = enhanced;
        source = ChatbotResponseSource.onlineEnhancement;
        return ChatbotResponse(
          text: text,
          intent: intent.intent,
          confidence: 0.95,
          isEmergency: false,
          source: source,
          language: nlp.language,
          intentResult: intent,
          suggestions: _suggestionsForIntent(intent.intent),
        );
      }
    }

    dialogueManager.completeTurn(
      conversationId: request.conversationId,
      userText: request.text,
      assistantText: text,
      intent: intent.intent,
      confidence: combinedConfidence,
    );

    return ChatbotResponse(
      text: text,
      intent: intent.intent,
      confidence: combinedConfidence,
      isEmergency: false,
      source: source,
      language: nlp.language,
      intentResult: intent,
      retrievedContexts: rag.contexts,
      suggestions: rag.suggestions,
      metadata: {
        'rag_method': rag.method,
        'matched_features': intent.matchedFeatures,
      },
    );
  }

  Future<TranslationResponse> translate(TranslationRequest request) async {
    await initialize();
    return translationManager.translate(request);
  }

  List<String> _suggestionsForIntent(String intent) {
    switch (intent) {
      case 'food_query':
        return ['Best local food', 'Vegetarian options', 'Dal bhat places'];
      case 'homestay_search':
        return [
          'Find homestay nearby',
          'Budget accommodation',
          'Village stays'
        ];
      case 'transport_query':
        return ['Bus routes', 'Jeep hire', 'Walking distance'];
      case 'best_time_to_visit':
        return ['Spring season', 'Autumn trekking', 'Monsoon travel'];
      case 'trekking':
        return ['Easy treks', 'Popular routes', 'Permit info'];
      default:
        return ['Destinations', 'Homestays', 'Food & Culture'];
    }
  }

  Future<Map<String, String>> _loadStringMap(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawMap = decoded['mappings'] as Map? ?? decoded;
      return rawMap
          .map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return const {
        'kati': 'कति',
        'khana': 'खाना',
        'basna': 'बस्न',
        'jana': 'जान',
        'najik': 'नजिक',
        'sasto': 'सस्तो',
        'shanta': 'शान्त',
        'gaun': 'गाउँ',
        'homestay': 'होमस्टे',
      };
    }
  }

  Future<Set<String>> _loadStringSet(String assetPath,
      {required String key}) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded[key] as List? ?? const [])
          .map((item) => item.toString())
          .toSet();
    } catch (_) {
      return const {'र', 'पनि', 'हो', 'छ', 'मा', 'को', 'ले', 'लाई'};
    }
  }

  Future<Map<String, Set<String>>> _loadOntology() async {
    try {
      final raw = await rootBundle.loadString(
        IntelligenceConstants.synonymOntologyAsset,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawSynonyms = decoded['synonyms'] as Map? ?? const {};
      return rawSynonyms.map((key, value) {
        final values = <String>{};
        if (value is Map) {
          for (final list in value.values) {
            if (list is List) {
              values.addAll(list.map((item) => item.toString()));
            }
          }
        }
        return MapEntry(key.toString(), values);
      });
    } catch (_) {
      return const {
        'budget': {'cheap', 'affordable', 'sasto', 'सस्तो'},
        'relaxation': {'peaceful', 'quiet', 'shanta', 'शान्त'},
        'trekking': {'hiking', 'trail', 'padayatra', 'ट्रेकिङ'},
      };
    }
  }

  Future<Map<String, String>> _loadDestinationGazetteer() async {
    try {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final decoded = jsonDecode(raw) as List;
      return {
        for (final item in decoded.whereType<Map>())
          if ((item['name']?.toString() ?? '').isNotEmpty)
            item['name'].toString():
                item['id']?.toString() ?? item['name'].toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, String>> _loadAccommodationGazetteer() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/accommodations.json');
      final decoded = jsonDecode(raw) as List;
      return {
        for (final item in decoded.whereType<Map>())
          if ((item['name']?.toString() ?? '').isNotEmpty)
            item['name'].toString():
                item['id']?.toString() ?? item['name'].toString(),
      };
    } catch (_) {
      return const {};
    }
  }
}
