import 'package:flutter/material.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
import '../theme/app_theme.dart';
import '../widgets/destination_card.dart';
import 'details_screen.dart';

class SavedTab extends StatelessWidget {
  final List<Destination> savedDestinations;
  final List<Accommodation> accommodations;
  final Future<void> Function(Destination) onToggleSaved;

  const SavedTab({
    super.key,
    required this.savedDestinations,
    required this.accommodations,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.snowWhite,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.earthOchre,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Places',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (savedDestinations.isNotEmpty)
                    Text(
                      '${savedDestinations.length} destination${savedDestinations.length == 1 ? '' : 's'}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: savedDestinations.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: savedDestinations.length,
              itemBuilder: (context, index) {
                final destination = savedDestinations[index];
                final cat = destination.category.isNotEmpty
                    ? destination.category.first
                    : 'scenic';
                final color = AppTheme.categoryColour(cat);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Stack(
                    children: [
                      DestinationCard(
                        destination: destination,
                        reasons: const ['Saved to your shortlist'],
                        scoreLabel: '♥',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(
                              destination: destination,
                              nearbyAccommodations: accommodations,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: GestureDetector(
                          onTap: () async => onToggleSaved(destination),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bookmark_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.earthOchre.withValues(alpha: 0.18),
                    AppTheme.earthOchre.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 44,
                color: AppTheme.earthOchre,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved places yet',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Browse destinations on the Home tab or get\nAI recommendations and bookmark the ones\nyou want to revisit.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _HintPill(
                  icon: Icons.home_rounded,
                  label: 'Browse Home',
                ),
                _HintPill(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Get AI Picks',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}