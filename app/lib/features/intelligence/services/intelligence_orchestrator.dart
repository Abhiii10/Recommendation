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
import 'package:rural_tourism_app/features/intelligence/models/entity_mention.dart';
import 'package:rural_tourism_app/features/intelligence/models/intent_classification_result.dart';
import 'package:rural_tourism_app/features/intelligence/models/language_detection_result.dart';
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
  late final Map<String, Map<String, dynamic>> _destinationById;

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
    final destinationRecords = await _loadDestinationRecords();
    _destinationById = {
      for (final item in destinationRecords)
        if ((item['id']?.toString() ?? '').isNotEmpty)
          item['id'].toString(): item,
    };
    final destinationGazetteer = _buildDestinationGazetteer(destinationRecords);
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

    final destinationMatch = _bestDestinationMatch(nlp.entities);
    if (destinationMatch != null) {
      return _directDestinationResponse(
        destinationMatch,
        nlp.language,
      );
    }

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
    final shouldAppendClarification = _shouldAppendLowConfidenceClarification(
        intent.intent, intent.confidence);
    var text = rag.text;
    var source = ChatbotResponseSource.offlineKnowledgeBase;
    if (shouldAppendClarification && rag.contexts.isNotEmpty) {
      text = _appendLowConfidenceClarification(text);
    } else if (rag.contexts.isEmpty &&
        intent.confidence < 0.25 &&
        dialogue.shouldClarify &&
        dialogue.clarificationQuestion != null) {
      text = dialogue.clarificationQuestion!;
      source = ChatbotResponseSource.offlineModel;
    }
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

  bool _shouldAppendLowConfidenceClarification(
    String intent,
    double confidence,
  ) {
    return intent != 'fallback' && confidence >= 0.35 && confidence < 0.55;
  }

  String _appendLowConfidenceClarification(String text) {
    const prompt = 'Did you mean: trekking tips / find homestay / safety info?';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return prompt;
    return '$trimmed\n\n$prompt';
  }

  EntityMention? _bestDestinationMatch(List<EntityMention> entities) {
    final destinations =
        entities.where((entity) => entity.type == EntityType.destination);
    if (destinations.isEmpty) return null;

    return destinations.reduce(
      (best, entity) => entity.confidence > best.confidence ? entity : best,
    );
  }

  ChatbotResponse _directDestinationResponse(
    EntityMention entity,
    LanguageDetectionResult language,
  ) {
    final destination = _destinationById[entity.canonicalId] ?? const {};
    final name = (destination['name'] ?? entity.text).toString();
    final district = (destination['district'] ?? '').toString();
    final description = (destination['full_description'] ??
            destination['short_description'] ??
            'This is a rural tourism destination in Gandaki Province.')
        .toString();
    final activities = _stringList(destination['activities']);
    final seasons = _stringList(destination['best_season']);
    final highlights = _stringList(destination['highlights']);
    final howToReach = (destination['how_to_reach'] ?? '').toString();

    final buffer = StringBuffer()
      ..writeln(
        district.isEmpty
            ? '$name is a destination in Nepal.'
            : '$name is in $district.',
      )
      ..writeln(description);

    if (activities.isNotEmpty) {
      buffer.writeln('Activities: ${activities.join(', ')}.');
    }
    if (seasons.isNotEmpty) {
      buffer.writeln('Best season: ${seasons.join(', ')}.');
    }
    if (highlights.isNotEmpty) {
      buffer.writeln('Highlights: ${highlights.take(4).join(', ')}.');
    }
    if (howToReach.isNotEmpty) {
      buffer.writeln('How to reach: $howToReach');
    }

    return ChatbotResponse(
      text: buffer.toString().trim(),
      intent: 'destination_query',
      confidence: 0.95,
      isEmergency: false,
      source: ChatbotResponseSource.offlineKnowledgeBase,
      language: language,
      intentResult: IntentClassificationResult(
        intent: 'destination_query',
        confidence: 0.95,
        alternatives: const {'destination_recommendation': 0.95},
        matchedFeatures: ['destination_gazetteer:${entity.text}'],
      ),
      suggestions: const ['Show on map', 'Find homestay nearby', 'Best season'],
      metadata: {
        'destination_id': entity.canonicalId,
        'destination_name': name,
      },
    );
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

  Future<List<Map<String, dynamic>>> _loadDestinationRecords() async {
    try {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> _buildDestinationGazetteer(
    List<Map<String, dynamic>> destinations,
  ) {
    final forms = <String, String>{};
    final firstTokenCounts = <String, int>{};

    for (final item in destinations) {
      final name = (item['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;
      final tokens = _nameTokens(name);
      if (tokens.isNotEmpty) {
        firstTokenCounts[tokens.first] =
            (firstTokenCounts[tokens.first] ?? 0) + 1;
      }
    }

    for (final item in destinations) {
      final id = (item['id']?.toString() ?? '').trim();
      final name = (item['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;

      final canonical = id.isNotEmpty ? id : name;
      for (final form in _destinationNameForms(name, firstTokenCounts)) {
        forms[form] = canonical;
      }
    }

    return forms;
  }

  List<String> _destinationNameForms(
    String name,
    Map<String, int> firstTokenCounts,
  ) {
    final genericSuffixes = {
      'base',
      'camp',
      'view',
      'viewpoint',
      'village',
      'lake',
      'riverside',
      'temple',
      'trail',
      'trek',
      'homestay',
      'area',
      'bazaar',
    };
    final tokens = _nameTokens(name);
    final forms = <String>{name};
    if (tokens.isEmpty) return forms.toList();

    var trimmed = List<String>.from(tokens);
    while (trimmed.length > 1 && genericSuffixes.contains(trimmed.last)) {
      trimmed = trimmed.sublist(0, trimmed.length - 1);
    }
    if (trimmed.length >= 2) {
      forms.add(trimmed.join(' '));
      forms.add(trimmed.take(2).join(' '));
    }
    final first = tokens.first;
    if (first.length >= 5 &&
        firstTokenCounts[first] == 1 &&
        !genericSuffixes.contains(first)) {
      forms.add(first);
    }

    return forms.toList();
  }

  List<String> _nameTokens(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value == null) return const [];
    return value
        .toString()
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
