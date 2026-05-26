import 'dart:math' as math;

class EmbeddingUtils {
  static int stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static List<double> normalize(List<double> values) {
    var norm = 0.0;
    for (final value in values) {
      norm += value * value;
    }
    if (norm == 0) return values;
    final scale = 1 / math.sqrt(norm);
    return values.map((value) => value * scale).toList(growable: false);
  }

  static Iterable<String> charNgrams(String text,
      {int min = 3, int max = 5}) sync* {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (var n = min; n <= max; n++) {
      if (compact.length < n) continue;
      for (var i = 0; i <= compact.length - n; i++) {
        yield compact.substring(i, i + n);
      }
    }
  }
}
