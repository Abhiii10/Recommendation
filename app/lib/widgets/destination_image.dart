import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/destination.dart';
import '../services/image_cache_service.dart';

class DestinationImage extends StatefulWidget {
  final Destination destination;
  final double height;
  final BoxFit fit;

  const DestinationImage({
    super.key,
    required this.destination,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<DestinationImage> createState() => _DestinationImageState();
}

class _DestinationImageState extends State<DestinationImage> {
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
    if (oldWidget.destination.id != widget.destination.id ||
        oldWidget.destination.name != widget.destination.name) {
      _resolveImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _shimmerPlaceholder();

    final networkUrl = _networkUrl;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: widget.fit,
        height: widget.height,
        width: double.infinity,
        errorWidget: (_, __, ___) => _localFallback(),
        placeholder: (_, __) => _shimmerPlaceholder(),
      );
    }

    return _localFallback();
  }

  Future<void> _resolveImage() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _networkUrl = null;
    });

    final url = await ImageCacheService.instance.resolveNetworkUrl(
      widget.destination.name,
      destinationId: widget.destination.id,
    );

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _networkUrl = url;
      _loading = false;
    });
  }

  Widget _localFallback() {
    return Image.asset(
      widget.destination.localFallbackAsset(),
      fit: widget.fit,
      height: widget.height,
      width: double.infinity,
    );
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
}
