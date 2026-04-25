import 'dart:convert';

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

    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .map((e) => Destination.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    throw Exception('Unexpected destinations JSON format.');
  }

  static Future<List<Accommodation>> loadAccommodations() async {
    final raw = await rootBundle.loadString(accommodationsPath);
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .map((e) => Accommodation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    throw Exception('Unexpected accommodations JSON format.');
  }

  static Future<Map<String, List<Map<String, dynamic>>>> loadSimilarPlaces() async {
    final raw = await rootBundle.loadString(similarPlacesPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw Exception('Unexpected recommendations JSON format.');
    }

    final out = <String, List<Map<String, dynamic>>>{};

    decoded.forEach((key, value) {
      out[key.toString()] = value is List
          ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
    });

    return out;
  }
}
