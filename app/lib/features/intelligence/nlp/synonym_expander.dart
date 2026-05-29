import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';

class SynonymExpander {
  final Map<String, Set<String>> ontology;

  const SynonymExpander({this.ontology = const {}});

  Set<String> expand(Iterable<String> terms) {
    final expanded = <String>{};
    for (final term in terms) {
      final normalized = TextUtils.normalizeSearchText(term);
      if (normalized.isEmpty) continue;
      expanded.add(normalized);
      for (final entry in ontology.entries) {
        if (entry.key == normalized || entry.value.contains(normalized)) {
          expanded
            ..add(entry.key)
            ..addAll(entry.value);
        }
      }
    }
    return expanded;
  }
}
