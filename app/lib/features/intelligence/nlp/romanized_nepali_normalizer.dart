import '../utils/text_utils.dart';

class RomanizedNepaliNormalizer {
  final Map<String, String> mappings;

  const RomanizedNepaliNormalizer({this.mappings = const {}});

  String normalize(String input) {
    final tokens = TextUtils.normalizeLatin(input).split(' ');
    return tokens.map(_normalizeToken).join(' ').trim();
  }

  String normalizeToDevanagari(String input) {
    final tokens = TextUtils.normalizeLatin(input).split(' ');
    return tokens
        .map((token) => mappings[_normalizeToken(token)] ?? token)
        .join(' ');
  }

  String _normalizeToken(String token) {
    if (token.isEmpty) return token;
    if (mappings.containsKey(token)) return token;

    const canonical = {
      'kti': 'kati',
      'khaana': 'khana',
      'bas': 'basna',
      'basne': 'basna',
      'jaane': 'jana',
      'jane': 'jana',
      'najikai': 'najik',
      'shant': 'shanta',
      'santa': 'shanta',
      'gau': 'gaun',
      'home': 'homestay',
      'home-stay': 'homestay',
    };

    if (canonical.containsKey(token)) return canonical[token]!;

    var best = token;
    var bestDistance = 3;
    for (final key in mappings.keys) {
      final distance = TextUtils.levenshtein(token, key, maxDistance: 2);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = key;
      }
    }
    return bestDistance <= 2 ? best : token;
  }
}
