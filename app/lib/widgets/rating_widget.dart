import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RatingWidget extends StatefulWidget {
  final int rating;
  final double size;
  final bool readOnly;
  final ValueChanged<int>? onRatingChanged;

  const RatingWidget({
    super.key,
    this.rating = 0,
    this.size = 24.0,
    this.readOnly = false,
    this.onRatingChanged,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  int _rating = 0;
  int? _animatedIndex;

  @override
  void initState() {
    super.initState();
    _rating = widget.rating.clamp(0, 5);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant RatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      _rating = widget.rating.clamp(0, 5);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int value) {
    if (widget.readOnly) return;

    HapticFeedback.selectionClick();
    setState(() {
      _rating = value;
      _animatedIndex = value;
    });
    widget.onRatingChanged?.call(value);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final filled = value <= _rating;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: widget.size,
          color: filled ? cs.primary : cs.surfaceContainerHighest,
        );

        final animatedStar = AnimatedBuilder(
          animation: _controller,
          child: star,
          builder: (context, child) {
            final scale = _animatedIndex == value && _controller.isAnimating
                ? _scale.value
                : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
        );

        if (widget.readOnly) {
          return Padding(
            padding:
                EdgeInsets.only(right: index == 4 ? 0 : widget.size * 0.08),
            child: animatedStar,
          );
        }

        return InkResponse(
          onTap: () => _select(value),
          radius: widget.size,
          containedInkWell: false,
          child: Padding(
            padding: EdgeInsets.only(
              right: index == 4 ? 0 : widget.size * 0.12,
            ),
            child: animatedStar,
          ),
        );
      }),
    );
  }
}
