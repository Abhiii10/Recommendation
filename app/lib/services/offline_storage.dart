import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';

class OfflineStorage {
  static const String syncedDestinationsPath =
      'assets/data/backend_destinations.json';
  static const String legacyDestinationsPath = 'assets/data/destinations.json';
  static const String accommodationsPath = 'assets/data/accommodations.json';
  static const String similarPlacesPath = 'assets/data/recommendations.json';

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
