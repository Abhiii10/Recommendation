import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DestinationImageGallery extends StatefulWidget {
  final List<String> images;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const DestinationImageGallery({
    super.key,
    required this.images,
    this.height = 300,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
    this.fit = BoxFit.cover,
  });

  @override
  State<DestinationImageGallery> createState() =>
      _DestinationImageGalleryState();
}

class _DestinationImageGalleryState extends State<DestinationImageGallery> {
  late final PageController _pageController;
  int _current = 0;

  List<String> get _images => widget.images
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant DestinationImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _current = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: images.isEmpty
            ? _emptyPlaceholder(context)
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => _current = index);
                    },
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: images[index],
                        fit: widget.fit,
                        width: double.infinity,
                        height: widget.height,
                        placeholder: (_, __) => _loadingPlaceholder(context),
                        errorWidget: (_, __, ___) => _errorPlaceholder(context),
                      );
                    },
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: _DotIndicator(
                        count: images.length,
                        current: _current,
                        onTap: (index) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _loadingPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
    );
  }

  Widget _emptyPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 46,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _errorPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: 42,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == current;
        return GestureDetector(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 7,
            height: active ? 7 : 7,
            decoration: BoxDecoration(
              color: active ? primary : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
