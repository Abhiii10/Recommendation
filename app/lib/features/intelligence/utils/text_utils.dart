class TextUtils {
  static bool isDevanagariCodeUnit(int codeUnit) =>
      codeUnit >= 0x0900 && codeUnit <= 0x097F;

  static bool isLatinCodeUnit(int codeUnit) =>
      (codeUnit >= 0x0041 && codeUnit <= 0x005A) ||
      (codeUnit >= 0x0061 && codeUnit <= 0x007A);

  static String compactWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String normalizeLatin(String value) {
    return compactWhitespace(
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), ' '),
    );
  }

  static String normalizeSearchText(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('\u0964', ' ')
        .replaceAll('\u0965', ' ')
        .replaceAll(RegExp(r'[!"#$%&()*+,./:;<=>?@\[\]^_`{|}~\r\n\t-]+'), ' ');
    return compactWhitespace(normalized);
  }

  static List<String> simpleTokens(String value) =>
      normalizeSearchText(value).split(' ').where((e) => e.isNotEmpty).toList();

  static bool containsPhrase(String input, String phrase) {
    final normalizedInput = normalizeSearchText(input);
    final normalizedPhrase = normalizeSearchText(phrase);
    if (normalizedPhrase.isEmpty) return false;
    if (normalizedPhrase.contains(' ')) {
      return normalizedInput.contains(normalizedPhrase);
    }
    return RegExp(
      '(^|\\s)${RegExp.escape(normalizedPhrase)}(\\s|\$)',
      caseSensitive: false,
    ).hasMatch(normalizedInput);
  }

  static int levenshtein(String a, String b, {int? maxDistance}) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (current[j] < rowMin) rowMin = current[j];
      }
      if (maxDistance != null && rowMin > maxDistance) {
        return maxDistance + 1;
      }
      final tmp = previous;
      previous = current;
      current = tmp;
    }

    return previous[b.length];
  }

  static double tokenJaccard(Iterable<String> a, Iterable<String> b) {
    final sa = a.where((e) => e.isNotEmpty).toSet();
    final sb = b.where((e) => e.isNotEmpty).toSet();
    if (sa.isEmpty || sb.isEmpty) return 0.0;
    final intersection = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}
