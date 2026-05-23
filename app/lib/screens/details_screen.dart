import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
import '../theme/app_theme.dart';
import '../widgets/destination_gallery.dart';

class DetailsScreen extends StatelessWidget {
  final Destination destination;
  final List<Accommodation>? nearbyAccommodations;
  final bool isSaved;
  final VoidCallback? onToggleSaved;

  const DetailsScreen({
    super.key,
    required this.destination,
    this.nearbyAccommodations,
    this.isSaved = false,
    this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stays = nearbyAccommodations ?? const <Accommodation>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.name),
        actions: [
          IconButton(
            tooltip: 'Share destination',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text: 'Check out ${destination.name} in Nepal!\n'
                      '${destination.shortDescription}\n\n'
                      'Discover it on Rural Tourism Guide.',
                  subject: destination.name,
                ),
              );
            },
          ),
          if (onToggleSaved != null)
            IconButton(
              tooltip: isSaved ? 'Remove from saved' : 'Save destination',
              onPressed: onToggleSaved,
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Hero(
            tag: 'dest-image-${destination.id}',
            child: DestinationGallery(
              destination: destination,
              height: 300,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.mountainTeal.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  style:
                      tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        destination.locationText,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(
                  icon: Icons.calendar_month_rounded,
                  label: destination.bestSeasonText,
                ),
                _StatPill(
                  icon: Icons.wallet_rounded,
                  label: destination.budgetLevel ?? 'Any budget',
                ),
                _StatPill(
                  icon: Icons.accessibility_new_rounded,
                  label: destination.accessibility ?? 'Open to all',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              destination.displayDescription,
              style: tt.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          if (destination.activities.isNotEmpty) ...[
            const _SectionHeader(title: 'Activities'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: destination.activities
                    .map(
                      (activity) => Chip(
                        avatar: const Icon(
                          Icons.directions_walk_rounded,
                          size: 14,
                        ),
                        label: Text(activity),
                        backgroundColor: cs.primaryContainer,
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (stays.isNotEmpty) ...[
            const _SectionHeader(title: 'Nearby Stays'),
            ...stays.map(
              (accommodation) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        Icons.hotel_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      accommodation.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${accommodation.type ?? 'Stay'}'
                      '${accommodation.priceRange != null ? ' - ${accommodation.priceRange}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
