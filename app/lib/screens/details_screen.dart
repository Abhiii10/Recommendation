import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(destination.description),
                const SizedBox(height: 16),
                _InfoLine(
                    label: 'District',
                    value: destination.district ?? 'Unknown'),
                _InfoLine(label: 'Type', value: destination.type),
                _InfoLine(label: 'Price Tier', value: destination.priceTier),
                _InfoLine(
                  label: 'Accessibility',
                  value: destination.accessibility ?? 'N/A',
                ),
                const SizedBox(height: 16),
                if (destination.activities.isNotEmpty) ...[
                  const Text(
                    'Activities',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: destination.activities
                        .map((activity) => Chip(label: Text(activity)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (nearbyAccommodations != null &&
                    nearbyAccommodations!.isNotEmpty) ...[
                  const Text(
                    'Nearby Accommodations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...nearbyAccommodations!.map(
                    (accommodation) => Card(
                      child: ListTile(
                        title: Text(accommodation.name),
                        subtitle: Text(
                          '${accommodation.type ?? 'Unknown'}'
                          '${accommodation.priceRange != null ? ' - ${accommodation.priceRange}' : ''}',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}
