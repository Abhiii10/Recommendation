import 'dart:convert';

import 'package:flutter/services.dart';

class JsonLoader {
  Future<Map<String, dynamic>> loadMap(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw FormatException('Expected JSON object in $assetPath');
  }

  Future<List<dynamic>> loadList(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    throw FormatException('Expected JSON array in $assetPath');
  }
}
