import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/destination.dart';
import '../theme/app_theme.dart';
import 'destination_image.dart';
import 'score_breakdown_widget.dart';

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

class DestinationCard extends StatelessWidget {
  final Destination destination;
  final List<String> reasons;
  final String scoreLabel;
  final VoidCallback onTap;
  final String? modeLabel;
  final IconData? modeIcon;
  final Widget? trailing;
  final Widget? footer;
  final List<String> badges;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.reasons,
    required this.scoreLabel,
    required this.onTap,
    this.modeLabel,
    this.modeIcon,
    this.trailing,
    this.footer,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cat =
        destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final catColor = AppTheme.categoryColourFor(context, cat);
    final catIcon = _iconFor(cat);
    final locationText = destination.locationText.trim().isEmpty
        ? 'Location details unavailable'
        : destination.locationText;

    final metaLabels = [
      destination.type,
      _budgetLabel(destination.priceTier),
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
          onTap();
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
                    if (modeLabel != null || trailing != null) ...[
                      Row(
                        children: [
                          if (modeLabel != null)
                            _ModePill(
                              label: modeLabel!,
                              icon: modeIcon ?? Icons.auto_awesome_rounded,
                              color: catColor,
                            ),
                          const Spacer(),
                          if (trailing != null) trailing!,
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
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: badges
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
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ReasonsPanel(reasons: reasons, color: catColor),
                    ],
                    if (scoreLabel != 'Saved') ...[
                      const SizedBox(height: 12),
                      _ScorePromptRow(
                        scoreLabel: scoreLabel,
                        scoreBreakdown: footer,
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
                destination: destination,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
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
              'Why this? >',
              style: TextStyle(
                fontSize: 11,
                color: cs.primary.withValues(alpha: 0.7),
              ),
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
