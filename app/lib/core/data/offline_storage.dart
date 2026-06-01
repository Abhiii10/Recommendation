import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';

class OfflineStorage {
  static const String syncedDestinationsPath =
      'assets/data/backend_destinations.json';
  static const String legacyDestinationsPath = 'assets/data/destinations.json';
  static const String accommodationsPath = 'assets/data/accommodations.json';
  static const String similarPlacesPath = 'assets/data/recommendations.json';
  static const String destinationEmbeddingsPath =
      'assets/data/destination_embeddings.json';
  static const String destinationEmbeddingMetaPath =
      'assets/data/embedding_meta.json';
  static const String legacyDestinationEmbeddingsPath =
      'assets/embeddings/destination_embeddings.json';

  static Future<List<Destination>> loadDestinations() async {
    String raw;

    try {
      raw = await rootBundle.loadString(syncedDestinationsPath);
    } catch (_) {
      raw = await rootBundle.loadString(legacyDestinationsPath);
    }

    final decoded = await compute(_parseJsonList, raw);
    return decoded.map(Destination.fromJson).toList();
  }

  static Future<List<Accommodation>> loadAccommodations() async {
    final raw = await rootBundle.loadString(accommodationsPath);
    final decoded = await compute(_parseJsonList, raw);
    return decoded.map(Accommodation.fromJson).toList();
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
      loadSimilarPlaces() async {
    final raw = await rootBundle.loadString(similarPlacesPath);
    return compute(_parseSimilarPlacesJson, raw);
  }

  static Future<Map<String, List<double>>> loadDestinationEmbeddings() async {
    try {
      final raw = await rootBundle.loadString(destinationEmbeddingsPath);
      final meta = await _loadOptionalString(destinationEmbeddingMetaPath);
      return compute(_parseDestinationEmbeddingsBundle, {
        'embeddings': raw,
        'meta': meta,
      });
    } catch (_) {
      try {
        final raw =
            await rootBundle.loadString(legacyDestinationEmbeddingsPath);
        return compute(_parseDestinationEmbeddingsBundle, {
          'embeddings': raw,
          'meta': '',
        });
      } catch (_) {
        return const {};
      }
    }
  }

  static Future<String> _loadOptionalString(String path) async {
    try {
      return rootBundle.loadString(path);
    } catch (_) {
      return '';
    }
  }
}

List<Map<String, dynamic>> _parseJsonList(String raw) {
  final decoded = jsonDecode(raw);

  if (decoded is List) {
    return decoded.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  throw Exception('Unexpected JSON list format.');
}

Map<String, List<Map<String, dynamic>>> _parseSimilarPlacesJson(String raw) {
  final decoded = jsonDecode(raw);

  if (decoded is! Map) {
    throw Exception('Unexpected recommendations JSON format.');
  }

  final out = <String, List<Map<String, dynamic>>>{};

  decoded.forEach((key, value) {
    out[key.toString()] = value is List
        ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : <Map<String, dynamic>>[];
  });

  return out;
}

Map<String, List<double>> _parseDestinationEmbeddingsBundle(
  Map<String, String> bundle,
) {
  final decoded = jsonDecode(bundle['embeddings'] ?? '');
  final metaRaw = bundle['meta'] ?? '';
  final meta = metaRaw.isEmpty ? const {} : jsonDecode(metaRaw);
  final quantized = meta is Map && meta['quantized'] == true;
  final scale =
      meta is Map ? (meta['scale'] as num?)?.toDouble() ?? 127.0 : 127.0;

  if (decoded is! Map) {
    throw Exception('Unexpected destination embeddings JSON format.');
  }

  final entries = decoded['entries'] is Map ? decoded['entries'] : decoded;
  if (entries is! Map) {
    throw Exception('Destination embeddings JSON is missing entries.');
  }

  final out = <String, List<double>>{};
  entries.forEach((key, value) {
    if (value is List) {
      final vector = value
          .whereType<num>()
          .map((item) => quantized ? item.toDouble() / scale : item.toDouble())
          .toList(growable: false);
      out[key.toString()] = _normaliseVector(vector);
    }
  });

  return out;
}

List<double> _normaliseVector(List<double> vector) {
  var sumSquares = 0.0;
  for (final value in vector) {
    sumSquares += value * value;
  }
  if (sumSquares == 0) {
    return vector;
  }

  final magnitude = sqrt(sumSquares);
  return vector.map((value) => value / magnitude).toList(growable: false);
}
