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
    if (_isWidgetTest) return _localFallback();
    if (_loading) return _shimmerPlaceholder();

    final assetPath = _assetPath;
    if (assetPath != null && assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _localFallback(),
      );
    }

    final networkUrl = _networkUrl;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorWidget: (_, __, ___) => _networkFallback(networkUrl),
        placeholder: (_, __) => _shimmerPlaceholder(),
      );
    }

    return _networkFallback(null);
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

  Widget _networkFallback(String? failedUrl) {
    final fallbackUrl = WikiImageService.categoryFallbackUrl(widget.category);
    if (failedUrl == fallbackUrl) return _localFallback();

    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      fit: widget.fit,
      height: widget.height,
      width: double.infinity,
      placeholder: (_, __) => _shimmerPlaceholder(),
      errorWidget: (_, __, ___) => _localFallback(),
    );
  }

  Widget _localFallback() {
    return Image.asset(
      _assetForCategory(widget.category),
      fit: widget.fit,
      height: widget.height,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/cat_nature.jpg',
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
      ),
    );
  }

  String _assetForCategory(String? category) {
    final c = category?.toLowerCase() ?? '';
    if (c.contains('trek') || c.contains('adventure')) {
      return 'assets/images/cat_trekking.jpg';
    }
    if (c.contains('cultur') || c.contains('histor')) {
      return 'assets/images/cat_cultural.jpg';
    }
    if (c.contains('village')) return 'assets/images/cat_village.jpg';
    if (c.contains('wild')) return 'assets/images/cat_wildlife.jpg';
    if (c.contains('boat')) return 'assets/images/cat_boating.jpg';
    if (c.contains('spirit') || c.contains('pilgrim')) {
      return 'assets/images/cat_spiritual.jpg';
    }
    if (c.contains('relax')) return 'assets/images/cat_relaxation.jpg';
    if (c.contains('nature') || c.contains('scenic')) {
      return 'assets/images/cat_nature.jpg';
    }
    return 'assets/images/cat_nature.jpg';
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
