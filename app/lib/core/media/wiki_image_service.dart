import 'dart:convert';

import 'package:http/http.dart' as http;

class WikiImageService {
  static final _cache = <String, String>{};

  const WikiImageService._();

  /// Fetch image URL for a place name.
  /// Priority: memory cache -> backend API -> Wikipedia direct ->
  /// Wikimedia page image -> Unsplash category fallback.
  static Future<String> getImageUrl({
    required String placeName,
    String? category,
    String backendBaseUrl = '',
  }) async {
    final cacheKey = _cacheKey(placeName);
    final cached = _cache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final backendUrl = await _fromBackend(
      placeName: placeName,
      backendBaseUrl: backendBaseUrl,
    );
    if (backendUrl != null) {
      _cache[cacheKey] = backendUrl;
      return backendUrl;
    }

    final wikiUrl = await _fromWikipedia(placeName);
    if (wikiUrl != null) {
      _cache[cacheKey] = wikiUrl;
      return wikiUrl;
    }

    final fallback = categoryFallbackUrl(category);
    _cache[cacheKey] = fallback;
    return fallback;
  }

  static String categoryFallbackUrl(String? category) {
    final c = category?.toLowerCase() ?? '';
    if (c.contains('trek') || c.contains('adventure')) {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800';
    }
    if (c.contains('cultur') || c.contains('histor')) {
      return 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800';
    }
    if (c.contains('village')) {
      return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800';
    }
    if (c.contains('wild')) {
      return 'https://images.unsplash.com/photo-1474511320723-9a56873867b5?w=800';
    }
    if (c.contains('nature')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800';
    }
    if (c.contains('spirit') || c.contains('pilgrim')) {
      return 'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=800';
    }
    if (c.contains('boat')) {
      return 'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?w=800';
    }
    return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800';
  }

  static Future<String?> _fromBackend({
    required String placeName,
    required String backendBaseUrl,
  }) async {
    final base = backendBaseUrl.trim();
    if (base.isEmpty) return null;

    try {
      final normalizedBase =
          base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final uri = Uri.parse(
        '$normalizedBase/destinations/${Uri.encodeComponent(placeName)}/image',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final url = decoded['image_url'] as String?;
      if (url == null || url.trim().isEmpty) return null;
      return url.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fromWikipedia(String placeName) async {
    for (final title in _candidateTitles(placeName)) {
      final summaryUrl = await _fromWikipediaSummary(title);
      if (summaryUrl != null) return summaryUrl;

      final pageImageUrl = await _fromWikipediaPageImage(title);
      if (pageImageUrl != null) return pageImageUrl;
    }
    return null;
  }

  static Future<String?> _fromWikipediaSummary(String title) async {
    try {
      final encoded = Uri.encodeComponent(title);
      final response = await http
          .get(
            Uri.parse(
              'https://en.wikipedia.org/api/rest_v1/page/summary/$encoded',
            ),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final thumbnail = decoded['thumbnail'];
      if (thumbnail is! Map<String, dynamic>) return null;

      final url = thumbnail['source'] as String?;
      if (url == null || url.trim().isEmpty) return null;
      return url.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fromWikipediaPageImage(String title) async {
    try {
      final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'titles': title,
        'prop': 'pageimages',
        'format': 'json',
        'pithumbsize': '800',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final query = decoded['query'];
      if (query is! Map<String, dynamic>) return null;
      final pages = query['pages'];
      if (pages is! Map<String, dynamic>) return null;

      for (final page in pages.values) {
        if (page is! Map<String, dynamic>) continue;
        final thumbnail = page['thumbnail'];
        if (thumbnail is! Map<String, dynamic>) continue;
        final url = thumbnail['source'] as String?;
        if (url != null && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<String> _candidateTitles(String placeName) {
    final trimmed = placeName.trim();
    if (trimmed.isEmpty) return const [];
    return [trimmed, '$trimmed, Nepal'];
  }

  static String _cacheKey(String placeName) {
    return placeName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
