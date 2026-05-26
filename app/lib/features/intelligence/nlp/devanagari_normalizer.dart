import '../utils/text_utils.dart';

class DevanagariNormalizer {
  const DevanagariNormalizer();

  String normalize(String input) {
    var value = input
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('।', '\u0964')
        .replaceAll('॥', '\u0965');

    const variants = {
      'गाउ': 'गाउँ',
      'गाउं': 'गाउँ',
      'होम स्टे': 'होमस्टे',
      'संग': 'सँग',
      'रुपैया': 'रुपैयाँ',
      'महंगो': 'महँगो',
      'काठमाडौ': 'काठमाडौं',
    };

    for (final entry in variants.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }

    return TextUtils.compactWhitespace(value);
  }
}
