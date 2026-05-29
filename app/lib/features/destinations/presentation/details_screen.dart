import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rural_tourism_app/core/utils/haversine.dart';
import 'package:rural_tourism_app/core/utils/stable_user_id.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/core/sync/interaction_sync_service.dart';
import 'package:rural_tourism_app/core/data/local_data_service.dart';
import 'package:rural_tourism_app/shared/theme/app_theme.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/destination_image_gallery.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/rating_widget.dart';
import 'package:rural_tourism_app/features/destinations/presentation/widgets/review_bottom_sheet.dart';

class DetailsScreen extends StatefulWidget {
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
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  static const double _kathmanduLat = 27.7172;
  static const double _kathmanduLng = 85.3240;

  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _loadReviews();
    unawaited(_logInteraction('detail_view'));
  }

  @override
  void didUpdateWidget(covariant DetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination.id != widget.destination.id) {
      _reviewsFuture = _loadReviews();
    }
  }

  Future<List<Map<String, dynamic>>> _loadReviews() {
    return LocalDataService.instance.getReviews(widget.destination.id);
  }

  void _refreshReviews() {
    if (!mounted) return;
    setState(() {
      _reviewsFuture = _loadReviews();
    });
  }

  void _openReviewSheet() {
    unawaited(
      showReviewBottomSheet(
        context: context,
        destinationId: widget.destination.id,
        onSubmitted: _refreshReviews,
        onRatingSubmitted: (rating) => _logInteraction(
          'rating',
          value: rating.toDouble(),
        ),
      ),
    );
  }

  Future<void> _logInteraction(
    String eventType, {
    double value = 1.0,
  }) async {
    try {
      final userId = await resolveStableUserId();

      await InteractionSyncService.instance.recordInteraction(
        userId: userId,
        destinationId: widget.destination.id,
        eventType: eventType,
        value: value,
      );
    } catch (_) {
      // Backend interaction logging should not block local details.
    }
  }

  void _toggleSaved() {
    final nextSaved = !widget.isSaved;
    unawaited(HapticFeedback.selectionClick());
    unawaited(_logInteraction(nextSaved ? 'save' : 'unsave'));
    widget.onToggleSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stays = widget.nearbyAccommodations ?? const <Accommodation>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.name),
        actions: [
          IconButton(
            tooltip: 'Share destination',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Check out ${destination.name} in Nepal!\n'
                        '${destination.shortDescription}\n\n'
                        'Discover it on Paila Nepal.',
                    subject: destination.name,
                  ),
                ),
              );
            },
          ),
          if (widget.onToggleSaved != null)
            IconButton(
              tooltip:
                  widget.isSaved ? 'Remove from saved' : 'Save destination',
              onPressed: _toggleSaved,
              icon: Icon(
                widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Hero(
            tag: 'dest-image-${destination.id}',
            child: DestinationImageGallery(
              images: destination.images,
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
          _TravelStatsRow(
            elevationLabel: 'Elevation TBD',
            distanceLabel: _distanceFromKathmandu(destination),
            adventureLevel: destination.adventureLevel,
          ),
          const _SectionHeader(title: 'Community Reviews'),
          _ReviewsSection(
            reviewsFuture: _reviewsFuture,
            onWriteReview: _openReviewSheet,
          ),
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

  String _distanceFromKathmandu(Destination destination) {
    final latitude = destination.latitude;
    final longitude = destination.longitude;

    if (latitude == null || longitude == null) {
      return 'Distance TBD';
    }

    final distance = haversineKm(
      _kathmanduLat,
      _kathmanduLng,
      latitude,
      longitude,
    );

    return '${distance.round()} km from Kathmandu';
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

class _TravelStatsRow extends StatelessWidget {
  final String elevationLabel;
  final String distanceLabel;
  final int? adventureLevel;

  const _TravelStatsRow({
    required this.elevationLabel,
    required this.distanceLabel,
    required this.adventureLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _InfoBadge(
            icon: Icons.height_rounded,
            label: elevationLabel,
          ),
          _InfoBadge(
            icon: Icons.route_rounded,
            label: distanceLabel,
          ),
          _DifficultyBadge(level: adventureLevel),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final int? level;

  const _DifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalizedLevel = (level ?? 0).clamp(0, 5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Difficulty',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 7),
          ...List.generate(5, (index) {
            final filled = index < normalizedLevel;
            return Icon(
              Icons.terrain_rounded,
              size: 14,
              color: filled ? cs.primary : cs.outlineVariant,
            );
          }),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> reviewsFuture;
  final VoidCallback onWriteReview;

  const _ReviewsSection({
    required this.reviewsFuture,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
        final average = _averageRating(reviews);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewSummary(
                average: average,
                count: reviews.length,
                onWriteReview: onWriteReview,
              ),
              if (reviews.isEmpty)
                const _EmptyReviews()
              else
                ...reviews.map((review) => _ReviewCard(review: review)),
            ],
          ),
        );
      },
    );
  }

  double? _averageRating(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) return null;

    final total = reviews.fold<double>(
      0,
      (sum, review) => sum + (review['rating'] as num).toDouble(),
    );
    return total / reviews.length;
  }
}

class _ReviewSummary extends StatelessWidget {
  final double? average;
  final int count;
  final VoidCallback onWriteReview;

  const _ReviewSummary({
    required this.average,
    required this.count,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          RatingWidget(
            rating: average?.round() ?? 0,
            size: 18,
            readOnly: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              average == null
                  ? 'No reviews yet'
                  : '${average!.toStringAsFixed(1)} average - $count ${count == 1 ? 'review' : 'reviews'}',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onWriteReview,
            icon: const Icon(Icons.rate_review_rounded, size: 16),
            label: const Text('Write a Review'),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Be the first traveller to leave a note for this place.',
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.6,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = review['review_text']?.toString().trim() ?? '';
    final createdAtRaw = review['created_at'] as int?;
    final createdAt = createdAtRaw == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(createdAtRaw);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingWidget(rating: rating, size: 16, readOnly: true),
              const Spacer(),
              Text(
                _relativeDate(createdAt),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              text,
              style: tt.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeDate(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }

    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    }

    if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    }

    if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    }

    return 'just now';
  }
}
