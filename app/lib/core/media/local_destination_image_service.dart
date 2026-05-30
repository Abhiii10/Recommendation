import 'dart:convert';

import 'package:flutter/services.dart';

class LocalDestinationImageService {
  static const _manifestPath = 'assets/data/destination_image_assets.json';
  static Map<String, String>? _manifest;

  const LocalDestinationImageService._();

  static Future<String?> getAssetPath(String placeName) async {
    final manifest = await _loadManifest();
    return manifest[_cacheKey(placeName)];
  }

  static Future<Map<String, String>> _loadManifest() async {
    final cached = _manifest;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_manifestPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _manifest = const {};
        return _manifest!;
      }

      _manifest = {
        for (final entry in decoded.entries)
          _cacheKey(entry.key): entry.value.toString(),
      };
      return _manifest!;
    } catch (_) {
      _manifest = const {};
      return _manifest!;
    }
  }

  static String _cacheKey(String placeName) {
    return placeName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
