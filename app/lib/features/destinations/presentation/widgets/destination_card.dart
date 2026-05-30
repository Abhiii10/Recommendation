import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/core/data/local_data_service.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/destination_image.dart';
import 'package:rural_tourism_app/features/recommendations/presentation/widgets/score_breakdown_widget.dart';

const _kCategoryIcons = <String, IconData>{
  'trekking': Icons.hiking_rounded,
  'cultural': Icons.account_balance_rounded,
  'culture': Icons.account_balance_rounded,
  'village': Icons.home_work_rounded,
  'nature': Icons.eco_rounded,
  'adventure': Icons.terrain_rounded,
  'relaxation': Icons.spa_rounded,
  'pilgrimage': Icons.temple_hindu_rounded,
  'wildlife': Icons.forest_rounded,
  'boating': Icons.sailing_rounded,
  'photography': Icons.camera_alt_rounded,
  'spiritual': Icons.brightness_5_rounded,
  'scenic': Icons.landscape_rounded,
  'historic': Icons.domain_rounded,
};

IconData _iconFor(String cat) =>
    _kCategoryIcons[cat.toLowerCase()] ?? Icons.place_rounded;

class DestinationCard extends StatefulWidget {
  final Destination destination;
  final List<String> reasons;
  final String scoreLabel;
  final VoidCallback onTap;
  final String? modeLabel;
  final IconData? modeIcon;
  final Widget? trailing;
  final Widget? insight;
  final Widget? footer;
  final List<String> badges;
  final bool? isSaved;
  final VoidCallback? onToggleSaved;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.reasons,
    required this.scoreLabel,
    required this.onTap,
    this.modeLabel,
    this.modeIcon,
    this.trailing,
    this.insight,
    this.footer,
    this.badges = const [],
    this.isSaved,
    this.onToggleSaved,
  });

  @override
  State<DestinationCard> createState() => _DestinationCardState();

  static String _budgetLabel(String value) {
    switch (value.toLowerCase()) {
      case 'budget':
        return 'Budget friendly';
      case 'medium':
        return 'Mid-range';
      case 'premium':
        return 'Premium';
      default:
        return value;
    }
  }
}

class _DestinationCardState extends State<DestinationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;
  late final Animation<double> _burstAnimation;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burstAnimation = CurvedAnimation(
      parent: _burstController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant DestinationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != true && widget.isSaved == true) {
      _burstController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _handleSaveTap() {
    unawaited(HapticFeedback.selectionClick());
    widget.onToggleSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final destination = widget.destination;
    final cat =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final catColor = AppTheme.categoryColourFor(context, cat);
    final catIcon = _iconFor(cat);
    final locationText = destination.locationText.trim().isEmpty
        ? 'Location details unavailable'
        : destination.locationText;

    final metaLabels = [
      destination.type,
      DestinationCard._budgetLabel(destination.priceTier),
      destination.bestSeasonText,
    ].where((label) => label.trim().isNotEmpty).take(3).toList();

    final tags = {
      ...destination.culturalTagList,
      ...destination.amenityList,
    }.where((tag) => tag.trim().isNotEmpty).take(4).toList();

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outlineVariant, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImageHeader(
                destination: destination,
                category: cat,
                icon: catIcon,
                locationText: locationText,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.modeLabel != null ||
                        widget.trailing != null ||
                        widget.onToggleSaved != null) ...[
                      Row(
                        children: [
                          if (widget.modeLabel != null)
                            _ModePill(
                              label: widget.modeLabel!,
                              icon:
                                  widget.modeIcon ?? Icons.auto_awesome_rounded,
                              color: catColor,
                            ),
                          const Spacer(),
                          _AverageRatingBadge(
                            destinationId: destination.id,
                            hasTrailing: widget.trailing != null ||
                                widget.onToggleSaved != null,
                          ),
                          if (widget.trailing != null) widget.trailing!,
                          if (widget.trailing != null &&
                              widget.onToggleSaved != null)
                            const SizedBox(width: 6),
                          if (widget.onToggleSaved != null)
                            _SaveBurstButton(
                              isSaved: widget.isSaved == true,
                              animation: _burstAnimation,
                              onTap: _handleSaveTap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (metaLabels.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: metaLabels
                            .map(
                              (label) =>
                                  _MetaChip(label: label, color: catColor),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      destination.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (widget.badges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.badges
                            .map((badge) => _BadgeChip(
                                  label: badge,
                                  color: catColor,
                                ))
                            .toList(),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            tags.map((tag) => _TagChip(label: tag)).toList(),
                      ),
                    ],
                    if (widget.reasons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ReasonsPanel(reasons: widget.reasons, color: catColor),
                    ],
                    if (widget.insight != null) ...[
                      const SizedBox(height: 14),
                      widget.insight!,
                    ],
                    if (widget.scoreLabel != 'Saved') ...[
                      const SizedBox(height: 12),
                      _ScorePromptRow(
                        scoreLabel: widget.scoreLabel,
                        scoreBreakdown: widget.footer,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Open destination profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: catColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: catColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBurstButton extends StatelessWidget {
  final bool isSaved;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _SaveBurstButton({
    required this.isSaved,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return IgnorePointer(
                child: CustomPaint(
                  size: const Size(46, 46),
                  painter: _BookmarkBurstPainter(
                    progress: animation.value,
                    color: cs.primary,
                  ),
                ),
              );
            },
          ),
          IconButton.filledTonal(
            tooltip: isSaved ? 'Remove from saved' : 'Save destination',
            onPressed: onTap,
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BookmarkBurstPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = size.center(Offset.zero);
    final distance = 8 + (progress * 22);
    final radius = 3.8 - (progress * 1.8);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final paint = Paint()..color = color.withValues(alpha: opacity);

    for (var i = 0; i < 6; i++) {
      final angle = (-math.pi / 2) + ((math.pi * 2) / 6 * i);
      final offset = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      canvas.drawCircle(center + offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BookmarkBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ImageHeader extends StatelessWidget {
  final Destination destination;
  final String category;
  final IconData icon;
  final String locationText;

  const _ImageHeader({
    required this.destination,
    required this.category,
    required this.icon,
    required this.locationText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
            child: Hero(
              tag: 'dest-image-${destination.id}',
              child: DestinationImage(
                destinationName: destination.name,
                category: category,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _cap(category),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AverageRatingBadge extends StatefulWidget {
  final String destinationId;
  final bool hasTrailing;

  const _AverageRatingBadge({
    required this.destinationId,
    required this.hasTrailing,
  });

  @override
  State<_AverageRatingBadge> createState() => _AverageRatingBadgeState();
}

class _AverageRatingBadgeState extends State<_AverageRatingBadge> {
  late Future<double?> _ratingFuture;

  @override
  void initState() {
    super.initState();
    _ratingFuture =
        LocalDataService.instance.getAverageRating(widget.destinationId);
  }

  @override
  void didUpdateWidget(covariant _AverageRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinationId != widget.destinationId) {
      _ratingFuture =
          LocalDataService.instance.getAverageRating(widget.destinationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: _ratingFuture,
      builder: (context, snapshot) {
        final rating = snapshot.data;
        if (rating == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(right: widget.hasTrailing ? 8 : 0),
          child: _RatingBadge(rating: rating),
        );
      },
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: cs.primary),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonsPanel extends StatelessWidget {
  final List<String> reasons;
  final Color color;

  const _ReasonsPanel({
    required this.reasons,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                'Why recommended',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...reasons.take(3).map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForReason(reason),
                        size: 15,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style:
                              theme.textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  IconData _iconForReason(String reason) {
    final value = reason.toLowerCase();
    if (value.contains('embedding') || value.contains('semantic')) {
      return Icons.psychology_alt_rounded;
    }
    if (value.contains('accommodation')) {
      return Icons.bed_rounded;
    }
    if (value.contains('season')) {
      return Icons.event_available_rounded;
    }
    if (value.contains('family')) {
      return Icons.family_restroom_rounded;
    }
    if (value.contains('budget')) {
      return Icons.savings_rounded;
    }
    if (value.contains('quality')) {
      return Icons.verified_rounded;
    }
    return Icons.check_circle_rounded;
  }
}

class _ScorePromptRow extends StatelessWidget {
  final String scoreLabel;
  final Widget? scoreBreakdown;

  const _ScorePromptRow({
    required this.scoreLabel,
    required this.scoreBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBreakdown = scoreBreakdown is ScoreBreakdownWidget ||
        (scoreBreakdown != null && scoreBreakdown is! SizedBox);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: hasBreakdown ? () => _showBreakdown(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 12, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              scoreLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const Spacer(),
            Text(
              'View score details',
              style: TextStyle(
                fontSize: 11,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 16,
              color: cs.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    HapticFeedback.selectionClick();
    final child = scoreBreakdown;
    if (child == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: child,
          ),
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withValues(alpha: 0.09),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.secondaryContainer.withValues(alpha: 0.45),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _cap(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
