import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../theme/app_theme.dart';

const _kCategoryIcons = <String, IconData>{
  'trekking':    Icons.hiking_rounded,
  'cultural':    Icons.account_balance_rounded,
  'culture':     Icons.account_balance_rounded,
  'village':     Icons.home_work_rounded,
  'nature':      Icons.eco_rounded,
  'adventure':   Icons.terrain_rounded,
  'relaxation':  Icons.spa_rounded,
  'pilgrimage':  Icons.temple_hindu_rounded,
  'wildlife':    Icons.forest_rounded,
  'boating':     Icons.sailing_rounded,
  'photography': Icons.camera_alt_rounded,
  'spiritual':   Icons.brightness_5_rounded,
  'scenic':      Icons.landscape_rounded,
  'historic':    Icons.domain_rounded,
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
    final theme        = Theme.of(context);
    final cs           = theme.colorScheme;
    final cat          = destination.category.isNotEmpty ? destination.category.first : 'scenic';
    final catColor     = AppTheme.categoryColour(cat);
    final catIcon      = _iconFor(cat);

    final metaLabels = [
      destination.type,
      _budgetLabel(destination.priceTier),
      destination.bestSeasonText,
    ].where((l) => l.trim().isNotEmpty).take(3).toList();

    final tags = {
      ...destination.culturalTagList,
      ...destination.amenityList,
    }.where((t) => t.trim().isNotEmpty).take(4).toList();

    final locationText = destination.locationText.trim().isEmpty
        ? 'Location details unavailable'
        : destination.locationText;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0E6E2), width: 1),
          ),
          child: Column(
            children: [
              // ── Colour header strip ──────────────────────────────────
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: icon + name + trailing ─────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon avatar with gradient
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                catColor.withValues(alpha: 0.20),
                                catColor.withValues(alpha: 0.08),
                              ],
                            ),
                            border: Border.all(color: catColor.withValues(alpha: 0.18), width: 1),
                          ),
                          child: Icon(catIcon, color: catColor, size: 26),
                        ),
                        const SizedBox(width: 14),

                        // Name, location, meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mode pill
                              if (modeLabel != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(modeIcon ?? Icons.auto_awesome_rounded,
                                          size: 12, color: catColor),
                                      const SizedBox(width: 5),
                                      Text(modeLabel!,
                                        style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w700, color: catColor,
                                        )),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              Text(
                                destination.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800, height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),

                              Row(
                                children: [
                                  Icon(Icons.place_outlined, size: 13, color: catColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(locationText,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant, height: 1.3,
                                      )),
                                  ),
                                ],
                              ),

                              if (metaLabels.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6, children: metaLabels.map(
                                  (l) => _MetaChip(label: l, color: catColor),
                                ).toList()),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Score + trailing
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (trailing != null) ...[trailing!, const SizedBox(height: 8)],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: catColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.auto_graph_rounded, size: 13, color: Colors.white),
                                  const SizedBox(height: 2),
                                  Text(scoreLabel,
                                    style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Description ──────────────────────────────────────
                    Text(
                      destination.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5, color: cs.onSurfaceVariant,
                      ),
                    ),

                    // ── Badges ───────────────────────────────────────────
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: badges.map(
                        (b) => _BadgeChip(label: b, color: catColor),
                      ).toList()),
                    ],

                    // ── Tags ─────────────────────────────────────────────
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: tags.map(
                        (t) => _TagChip(label: t),
                      ).toList()),
                    ],

                    // ── Why recommended ──────────────────────────────────
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: catColor.withValues(alpha: 0.14), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.tips_and_updates_outlined, size: 16, color: catColor),
                              const SizedBox(width: 6),
                              Text('Why recommended',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800, color: catColor,
                                )),
                            ]),
                            const SizedBox(height: 10),
                            ...reasons.take(3).map((reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Container(
                                      width: 5, height: 5,
                                      decoration: BoxDecoration(
                                        color: catColor, shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(reason,
                                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45))),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],

                    // ── Score breakdown footer ────────────────────────────
                    if (footer != null) ...[const SizedBox(height: 14), footer!],

                    // ── CTA row ──────────────────────────────────────────
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('Open destination profile',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: catColor, fontWeight: FontWeight.w700,
                          )),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: catColor),
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
      case 'budget':  return 'Budget friendly';
      case 'medium':  return 'Mid-range';
      case 'premium': return 'Premium';
      default:        return value;
    }
  }
}

// ── Chip variants ──────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaChip({required this.label, required this.color});

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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
      child: Text(label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: cs.onSecondaryContainer,
        )),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

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
          Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}