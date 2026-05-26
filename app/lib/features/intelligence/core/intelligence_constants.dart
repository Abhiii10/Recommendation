class IntelligenceConstants {
  static const dataRoot = 'assets/data/intelligence';
  static const embeddingsRoot = 'assets/embeddings';

  static const knowledgeBaseAsset = '$dataRoot/knowledge_base_enhanced.json';
  static const phrasebookAsset = '$dataRoot/phrasebook_enhanced.json';
  static const translationTemplatesAsset =
      '$dataRoot/translation_templates.json';
  static const tourismGlossaryAsset = '$dataRoot/tourism_glossary.json';
  static const synonymOntologyAsset = '$dataRoot/synonym_ontology.json';
  static const nepaliStopwordsAsset = '$dataRoot/nepali_stopwords.json';
  static const romanizedDictionaryAsset = '$dataRoot/romanized_dictionary.json';
  static const emergencyContactsAsset =
      '$dataRoot/emergency_contacts_nepal.json';
  static const intentExamplesAsset = '$dataRoot/intent_examples.json';
  static const dialogueSlotsAsset = '$dataRoot/dialogue_slots_schema.json';
  static const clarificationTemplatesAsset =
      '$dataRoot/clarification_templates.json';
  static const responseTemplatesAsset = '$dataRoot/response_templates.json';

  static const knowledgeEmbeddingsAsset =
      '$embeddingsRoot/knowledge_embeddings.bin';
  static const embeddingMetadataAsset =
      '$embeddingsRoot/embedding_metadata.json';

  static const fallbackEmbeddingDimension = 96;
  static const maxRetrievedContext = 5;
}
