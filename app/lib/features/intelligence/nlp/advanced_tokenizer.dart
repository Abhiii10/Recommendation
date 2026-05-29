import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';

class AdvancedTokenizer {
  const AdvancedTokenizer();

  List<String> tokenize(String input) {
    final normalized = input
        .replaceAll('\u0964', ' ')
        .replaceAll('\u0965', ' ')
        .replaceAll(RegExp(r'[!"#$%&()*+,./:;<=>?@\[\]^_`{|}~\r\n\t]+'), ' ');
    return TextUtils.compactWhitespace(normalized)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }
}
