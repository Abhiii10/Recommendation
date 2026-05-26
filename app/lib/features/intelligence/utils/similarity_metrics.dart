import 'dart:math' as math;

class SimilarityMetrics {
  static double cosine(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    if (length == 0) return 0.0;

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static List<double> l2Normalize(List<double> values) {
    var norm = 0.0;
    for (final value in values) {
      norm += value * value;
    }
    if (norm == 0) return values;
    final scale = 1 / math.sqrt(norm);
    return values.map((value) => value * scale).toList(growable: false);
  }
}
