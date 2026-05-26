import '../core/intelligence_constants.dart';
import '../models/embedding_vector.dart';
import '../utils/text_utils.dart';
import 'embedding_utils.dart';

class EmbeddingEncoder {
  final int dimension;

  const EmbeddingEncoder({
    this.dimension = IntelligenceConstants.fallbackEmbeddingDimension,
  });

  EmbeddingVector encode(String text) {
    final vector = List<double>.filled(dimension, 0);
    final normalized = TextUtils.normalizeSearchText(text);
    final tokens = TextUtils.simpleTokens(normalized);

    for (final token in tokens) {
      final tokenIndex = EmbeddingUtils.stableHash('tok:$token') % dimension;
      vector[tokenIndex] += 1.0;
    }

    for (final ngram in EmbeddingUtils.charNgrams(normalized)) {
      final index = EmbeddingUtils.stableHash('ng:$ngram') % dimension;
      vector[index] += 0.35;
    }

    return EmbeddingVector(EmbeddingUtils.normalize(vector));
  }
}
