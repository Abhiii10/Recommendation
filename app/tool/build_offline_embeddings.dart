import 'dart:convert';
import 'dart:io';

import 'package:rural_tourism_app/models/destination.dart';
import 'package:rural_tourism_app/services/offline_semantic_encoder.dart';

void main() {
  final destinations =
      _loadDestinations('assets/data/backend_destinations.json');
  final entries = <String, List<double>>{};
  final entryMapping = <String, int>{};

  for (var index = 0; index < destinations.length; index++) {
    final destination = destinations[index];
    entries[destination.id] = OfflineSemanticEncoder.encodeDestination(
      destination,
    ).map((value) => double.parse(value.toStringAsFixed(6))).toList();
    entryMapping[destination.id] = index;
  }

  final embeddingsDir = Directory('assets/embeddings')
    ..createSync(recursive: true);
  final generatedAt = DateTime.now().toUtc().toIso8601String();

  File('${embeddingsDir.path}/destination_embeddings.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'model_name': OfflineSemanticEncoder.modelName,
      'embedding_dim': OfflineSemanticEncoder.dimension,
      'num_entries': entries.length,
      'created_at': generatedAt,
      'normalization': 'L2',
      'entries': entries,
    }),
  );

  File('${embeddingsDir.path}/embedding_metadata.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'model_name': OfflineSemanticEncoder.modelName,
      'embedding_dim': OfflineSemanticEncoder.dimension,
      'num_entries': entries.length,
      'entry_mapping': entryMapping,
      'created_at': generatedAt,
      'normalization': 'L2',
      'source': 'assets/data/backend_destinations.json',
      'fallback': 'Runtime semantic hashing is used for missing vectors.',
    }),
  );

  print('Generated ${entries.length} offline destination embeddings.');
  print('Model: ${OfflineSemanticEncoder.modelName}');
}

List<Destination> _loadDestinations(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  return decoded
      .map(
        (item) => Destination.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}
