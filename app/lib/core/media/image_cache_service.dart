import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';

class ImageCacheService {
  static final _productionInstance = ImageCacheService._();
  static ImageCacheService? _debugInstance;

  static ImageCacheService get instance =>
      _debugInstance ?? _productionInstance;

  @visibleForTesting
  static set debugInstance(ImageCacheService? service) {
    _debugInstance = service;
  }

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

  Future<List<String>> resolveGallery(
    String destinationName, {
    String? destinationId,
    int maxImages = 5,
  }) async {
    final name = destinationName.trim();
    if (name.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'img_gallery_${destinationId ?? name}';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      if (cached.isEmpty || cached == '[]') return [];
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          return decoded
              .map((url) => url.toString())
              .where((url) => url.trim().isNotEmpty)
              .toList();
        }
      } on FormatException {
        // Ignore malformed cache and refresh from Wikimedia.
      }
    }

    final urls = <String>[];

    final primary = await _fetchGallery(name, maxImages: maxImages);
    urls.addAll(primary);

    if (urls.length < 2) {
      final fallback = await _fetchGallery(
        '$name Nepal',
        maxImages: maxImages,
      );
      for (final url in fallback) {
        if (!urls.contains(url)) urls.add(url);
        if (urls.length >= maxImages) break;
      }
    }

    if (urls.isEmpty) {
      await prefs.setString(cacheKey, '[]');
      return [];
    }

    final limited = urls.take(maxImages).toList();
    await prefs.setString(cacheKey, jsonEncode(limited));
    return limited;
  }

  Future<void> prefetchGalleries(List<Destination> destinations) async {
    for (final destination in destinations) {
      await resolveGallery(
        destination.name,
        destinationId: destination.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
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

  Future<List<String>> _fetchGallery(
    String pageTitle, {
    required int maxImages,
  }) async {
    final encodedName = Uri.encodeComponent(pageTitle.trim());
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/media-list/$encodedName',
    );

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      final items = decoded['items'];
      if (items is! List) return [];

      const skipWords = [
        'flag',
        'Flag',
        'icon',
        'Icon',
        'logo',
        'Logo',
        'map',
        'Map',
        'symbol',
        'Symbol',
        'seal',
        'Seal',
        'coat',
        'Coat',
        'blank',
        'relief',
        '.svg',
        'SVG',
        'locator',
        'Locator',
        'emblem',
        'Emblem',
      ];

      final found = <String>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] != 'image') continue;

        final srcset = item['srcset'];
        if (srcset is! List || srcset.isEmpty) continue;

        String? bestSrc;
        var bestScale = -1.0;
        for (final entry in srcset) {
          if (entry is! Map<String, dynamic>) continue;
          final src = entry['src']?.toString() ?? '';
          final scaleStr = entry['scale']?.toString() ?? '1x';
          final scale = double.tryParse(scaleStr.replaceAll('x', '')) ?? 1.0;
          if (src.isNotEmpty && scale > bestScale) {
            bestScale = scale;
            bestSrc = src;
          }
        }

        if (bestSrc == null || bestSrc.isEmpty) continue;

        final shouldSkip = skipWords.any(bestSrc.contains);
        if (shouldSkip) continue;

        final url = bestSrc.startsWith('//') ? 'https:$bestSrc' : bestSrc;
        found.add(url);
        if (found.length >= maxImages) break;
      }

      return found;
    } on TimeoutException {
      return [];
    } on http.ClientException {
      return [];
    } on FormatException {
      return [];
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
