import '../utils/text_utils.dart';

class StopwordRemover {
  final Set<String> nepaliStopwords;
  final Set<String> englishStopwords;
  final Set<String> preservedTerms;

  const StopwordRemover({
    this.nepaliStopwords = const {},
    this.englishStopwords = _defaultEnglishStopwords,
    this.preservedTerms = _tourismContentTerms,
  });

  List<String> remove(Iterable<String> tokens) {
    return tokens.where((token) {
      final normalized = TextUtils.normalizeSearchText(token);
      if (normalized.isEmpty) return false;
      if (preservedTerms.contains(normalized)) return true;
      if (englishStopwords.contains(normalized)) return false;
      if (nepaliStopwords.contains(token) ||
          nepaliStopwords.contains(normalized)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static const _defaultEnglishStopwords = {
    'a',
    'an',
    'and',
    'are',
    'be',
    'can',
    'do',
    'for',
    'from',
    'how',
    'i',
    'in',
    'is',
    'it',
    'me',
    'of',
    'on',
    'or',
    'please',
    'the',
    'there',
    'this',
    'to',
    'what',
    'where',
    'with',
    'you',
  };

  static const _tourismContentTerms = {
    'homestay',
    'trekking',
    'food',
    'budget',
    'emergency',
    'police',
    'ambulance',
    'temple',
    'village',
    'सस्तो',
    'शान्त',
    'होमस्टे',
    'ट्रेकिङ',
  };
}
