import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../core/intelligence_constants.dart';
import '../core/intelligence_logger.dart';
import '../models/embedding_vector.dart';
import '../models/knowledge_entry.dart';

class PrecomputedEmbeddingsLoader {
  final IntelligenceLogger logger;

  const PrecomputedEmbeddingsLoader({
    this.logger = const IntelligenceLogger('EmbeddingsLoader'),
  });

  Future<Map<String, EmbeddingVector>> loadForEntries(
    List<KnowledgeEntry> entries,
  ) async {
    try {
      final data = await rootBundle.load(
        IntelligenceConstants.knowledgeEmbeddingsAsset,
      );
      if (data.lengthInBytes < 8) return const {};

      final bytes = data.buffer.asByteData();
      final count = bytes.getUint32(0, Endian.little);
      final dimension = bytes.getUint32(4, Endian.little);
      final expectedBytes = 8 + count * dimension * 4;
      if (data.lengthInBytes < expectedBytes || count != entries.length) {
        return const {};
      }

      final vectors = <String, EmbeddingVector>{};
      var offset = 8;
      for (var i = 0; i < count; i++) {
        final values = List<double>.generate(dimension, (_) {
          final value = bytes.getFloat32(offset, Endian.little);
          offset += 4;
          return value;
        }, growable: false);
        vectors[entries[i].id] = EmbeddingVector(values);
      }
      return vectors;
    } catch (error) {
      logger.warning('Using fallback hashed embeddings', error);
      return const {};
    }
  }
}
