import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';

class ImageCacheService {
  static final instance = ImageCacheService._();

  ImageCacheService._();

  static const _cachePrefix = 'img_cache_';
  static const _userAgent = 'RuralTourismGuide/1.0';

  Future<String?> resolveNetworkUrl(
    String destinationName, {
    String? destinationId,
  }) async {
    final name = destinationName.trim();
    if (name.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(destinationId ?? name);
    final cached = prefs.getString(cacheKey);
    if (cached != null) return cached.isEmpty ? null : cached;

    final primary = await _fetchThumbnail(name);
    if (primary.url != null) {
      await prefs.setString(cacheKey, primary.url!);
      return primary.url;
    }

    final fallback = await _fetchThumbnail('$name Nepal');
    if (fallback.url != null) {
      await prefs.setString(cacheKey, fallback.url!);
      return fallback.url;
    }

    if (primary.cacheableMiss && fallback.cacheableMiss) {
      await prefs.setString(cacheKey, '');
    }

    return null;
  }

  Future<void> prefetchAll(List<Destination> destinations) async {
    for (final destination in destinations) {
      await resolveNetworkUrl(
        destination.name,
        destinationId: destination.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<_ThumbnailResult> _fetchThumbnail(String pageTitle) async {
    final encodedName = Uri.encodeComponent(pageTitle.trim());
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedName',
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        return const _ThumbnailResult.miss(cacheableMiss: true);
      }

      if (response.statusCode != 200) {
        return const _ThumbnailResult.miss(cacheableMiss: false);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _ThumbnailResult.miss(cacheableMiss: true);
      }

      final thumbnail = decoded['thumbnail'];
      if (thumbnail is Map<String, dynamic>) {
        final source = thumbnail['source']?.toString().trim();
        if (source != null && source.isNotEmpty) {
          return _ThumbnailResult.hit(source);
        }
      }

      return const _ThumbnailResult.miss(cacheableMiss: true);
    } on TimeoutException {
      return const _ThumbnailResult.miss(cacheableMiss: false);
    } on http.ClientException {
      return const _ThumbnailResult.miss(cacheableMiss: false);
    } on FormatException {
      return const _ThumbnailResult.miss(cacheableMiss: true);
    }
  }

  Map<String, String> get _headers {
    if (kIsWeb) return const {};
    return const {'User-Agent': _userAgent};
  }

  String _cacheKey(String rawId) {
    final normalized = rawId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return '$_cachePrefix${normalized.isEmpty ? 'unknown' : normalized}';
  }
}

class _ThumbnailResult {
  final String? url;
  final bool cacheableMiss;

  const _ThumbnailResult.hit(this.url) : cacheableMiss = false;

  const _ThumbnailResult.miss({required this.cacheableMiss}) : url = null;
}
