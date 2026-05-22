import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/destination.dart';
import '../services/image_cache_service.dart';
import 'destination_image.dart';

class DestinationGallery extends StatefulWidget {
  final Destination destination;
  final double height;

  const DestinationGallery({
    super.key,
    required this.destination,
    this.height = 300,
  });

  @override
  State<DestinationGallery> createState() => _DestinationGalleryState();
}

class _DestinationGalleryState extends State<DestinationGallery> {
  List<String> _urls = [];
  bool _loading = true;
  int _current = 0;
  int _requestId = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadGallery();
  }

  @override
  void didUpdateWidget(covariant DestinationGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination.id != widget.destination.id) {
      setState(() {
        _urls = [];
        _loading = true;
        _current = 0;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _loadGallery();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              _loadingFallback()
            else if (_urls.isEmpty)
              DestinationImage(
                destination: widget.destination,
                height: widget.height,
                fit: BoxFit.cover,
              )
            else
              PageView.builder(
                controller: _pageController,
                itemCount: _urls.length,
                onPageChanged: (index) => setState(() => _current = index),
                itemBuilder: (_, index) => CachedNetworkImage(
                  imageUrl: _urls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: widget.height,
                  placeholder: (_, __) => _loadingFallback(),
                  errorWidget: (_, __, ___) => DestinationImage(
                    destination: widget.destination,
                    height: widget.height,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            if (!_loading && _urls.length > 1)
              Positioned(
                top: 14,
                right: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_current + 1} / ${_urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!_loading && _urls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_urls.length, (index) {
                    final active = index == _current;
                    return GestureDetector(
                      onTap: () => _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadGallery() async {
    final id = ++_requestId;
    final urls = await ImageCacheService.instance.resolveGallery(
      widget.destination.name,
      destinationId: widget.destination.id,
    );

    if (!mounted || id != _requestId) return;

    if (urls.isNotEmpty) {
      setState(() {
        _urls = urls;
        _loading = false;
      });
      return;
    }

    final single = await ImageCacheService.instance.resolveNetworkUrl(
      widget.destination.name,
      destinationId: widget.destination.id,
    );

    if (!mounted || id != _requestId) return;

    setState(() {
      _urls = single == null || single.isEmpty ? [] : [single];
      _loading = false;
    });
  }

  Widget _loadingFallback() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _localFallbackImage(),
        Opacity(
          opacity: 0.18,
          child: _shimmer(),
        ),
      ],
    );
  }

  Widget _localFallbackImage() {
    return Image.asset(
      widget.destination.localFallbackAsset(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: widget.height,
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: widget.height,
      ),
    );
  }
}
