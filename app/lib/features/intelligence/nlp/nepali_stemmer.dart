import '../utils/text_utils.dart';

enum NepaliStemmingMode { light, aggressive }

class NepaliStemmer {
  final NepaliStemmingMode mode;
  final Set<String> protectedTerms;

  const NepaliStemmer({
    this.mode = NepaliStemmingMode.light,
    this.protectedTerms = const {},
  });

  String stem(String token) {
    if (token.length < 3 || protectedTerms.contains(token)) return token;
    final hasDevanagari = token.codeUnits.any(TextUtils.isDevanagariCodeUnit);
    if (!hasDevanagari) return _stemLatin(token);

    var value = token;
    value = _stripSuffix(value,
        const ['लाई', 'बाट', 'सँग', 'संग', 'को', 'का', 'की', 'ले', 'मा']);
    if (mode == NepaliStemmingMode.aggressive) {
      value =
          _stripSuffix(value, const ['हरू', 'हरु', 'देखि', 'एको', 'ेको', 'ने']);
      value = _stripSuffix(value, const ['आउनु', 'जानु', 'गर्नु', 'हुनु']);
      value = _stripVowelSigns(value);
    }
    return value.length >= 2 ? value : token;
  }

  List<String> stemAll(Iterable<String> tokens) =>
      tokens.map(stem).where((token) => token.isNotEmpty).toList();

  String _stripSuffix(String value, List<String> suffixes) {
    for (final suffix in suffixes) {
      if (value.endsWith(suffix) && value.length - suffix.length >= 2) {
        return value.substring(0, value.length - suffix.length);
      }
    }
    return value;
  }

  String _stripVowelSigns(String value) {
    final stripped = value.replaceAll(RegExp('[ँंैेीूो]'), '');
    return stripped.length >= 2 ? stripped : value;
  }

  String _stemLatin(String token) {
    if (token.length > 5 && token.endsWith('ing')) {
      return token.substring(0, token.length - 3);
    }
    if (token.length > 4 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }
}
