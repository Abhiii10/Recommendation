import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rural_tourism_app/l10n/app_localizations.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/domain/services/accommodation_matcher.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/destination_card.dart';
import 'package:rural_tourism_app/shared/widgets/empty_state_widget.dart';
import 'package:rural_tourism_app/features/destinations/presentation/details_screen.dart';
import 'package:rural_tourism_app/features/trip_planner/presentation/trip_planner_screen.dart';

class SavedTab extends StatelessWidget {
  final List<Destination> savedDestinations;
  final List<Accommodation> accommodations;
  final Future<void> Function(Destination) onToggleSaved;
  final VoidCallback? onOpenAbout;

  const SavedTab({
    super.key,
    required this.savedDestinations,
    required this.accommodations,
    required this.onToggleSaved,
    this.onOpenAbout,
  });

  void _openTripPlanner(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripPlannerScreen(
          savedDestinations: savedDestinations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
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
                  Text(
                    l10n.savedTitle,
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
        actions: [
          if (onOpenAbout != null)
            IconButton(
              tooltip: 'About',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: onOpenAbout,
            ),
        ],
      ),
      body: savedDestinations.isEmpty
          ? const EmptyStateWidget(
              title: 'No saved destinations yet',
              subtitle:
                  'Your shortlist is lighter than a tea-house daypack. Bookmark a place when one feels right.',
              icon: Icons.bookmark_border_rounded,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: savedDestinations.length,
              itemBuilder: (context, index) {
                final destination = savedDestinations[index];
                final cat = destination.category.isNotEmpty
                    ? destination.category.first
                    : 'scenic';
                final color = AppTheme.categoryColourFor(context, cat);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Stack(
                    children: [
                      DestinationCard(
                        destination: destination,
                        reasons: const ['Saved to your shortlist'],
                        scoreLabel: 'Saved',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(
                              destination: destination,
                              nearbyAccommodations:
                                  accommodationsForDestination(
                                destination,
                                accommodations,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Semantics(
                          label: 'Remove from saved',
                          button: true,
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await onToggleSaved(destination);
                            },
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
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'saved_tab_plan_trip_fab',
        onPressed: () => _openTripPlanner(context),
        icon: const Icon(Icons.route_rounded),
        label: const Text('Plan a Trip'),
      ),
    );
  }
}
