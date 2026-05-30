import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:rural_tourism_app/core/media/local_destination_image_service.dart';
import 'package:rural_tourism_app/core/media/wiki_image_service.dart';
import 'package:rural_tourism_app/core/utils/backend_config.dart';

class DestinationImage extends StatefulWidget {
  final String destinationName;
  final double height;
  final BoxFit fit;
  final String? category;

  const DestinationImage({
    super.key,
    required this.destinationName,
    required this.height,
    this.fit = BoxFit.cover,
    this.category,
  });

  @override
  State<DestinationImage> createState() => _DestinationImageState();
}

class _DestinationImageState extends State<DestinationImage> {
  static const _categoryFallbacks = {
    'trekking':
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    'adventure':
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    'cultural':
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
    'culture':
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
    'historic':
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
    'village':
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    'wildlife':
        'https://images.unsplash.com/photo-1474511320723-9a56873867b5?w=800&q=80',
    'boating':
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?w=800&q=80',
    'spiritual':
        'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=800&q=80',
    'pilgrimage':
        'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=800&q=80',
    'relaxation':
        'https://images.unsplash.com/photo-1540206395-68808572332f?w=800&q=80',
    'nature':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
    'scenic':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
  };

  static const _defaultFallback =
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80';

  String? _assetPath;
  String? _networkUrl;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant DestinationImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinationName != widget.destinationName ||
        oldWidget.category != widget.category) {
      _resolveImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isWidgetTest) return _fallbackIcon();
    if (_loading) return _shimmerPlaceholder();

    final assetPath = _assetPath;
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image(
        image: AssetImage(assetPath),
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _ultimateFallback(),
      );
    }

    final networkUrl = _networkUrl;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorWidget: (_, __, ___) => _ultimateFallback(),
        placeholder: (_, __) => _shimmerPlaceholder(),
      );
    }

    return _ultimateFallback();
  }

  Future<void> _resolveImage() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _assetPath = null;
      _networkUrl = null;
    });

    if (_isWidgetTest) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _loading = false);
      return;
    }

    final assetPath = await LocalDestinationImageService.getAssetPath(
      widget.destinationName,
    );
    if (!mounted || requestId != _requestId) return;
    if (assetPath != null && assetPath.isNotEmpty) {
      setState(() {
        _assetPath = assetPath;
        _loading = false;
      });
      return;
    }

    final url = await WikiImageService.getImageUrl(
      placeName: widget.destinationName,
      category: widget.category,
      backendBaseUrl: backendBaseUrl,
    );

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _networkUrl = url;
      _loading = false;
    });
  }

  Widget _ultimateFallback() {
    return CachedNetworkImage(
      imageUrl: _urlForCategory(widget.category),
      fit: widget.fit,
      height: widget.height,
      width: double.infinity,
      placeholder: (_, __) => _shimmerPlaceholder(),
      errorWidget: (_, __, ___) => _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: const Color(0xFF1E3A2F),
      child: const Center(
        child: Icon(
          Icons.landscape_rounded,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  static String _urlForCategory(String? category) {
    final c = category?.toLowerCase() ?? '';
    for (final entry in _categoryFallbacks.entries) {
      if (c.contains(entry.key)) return entry.value;
    }
    return _defaultFallback;
  }

  Widget _shimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }
}
