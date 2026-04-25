import 'package:flutter/material.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';

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
          if (onToggleSaved != null)
            IconButton(
              onPressed: onToggleSaved,
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            destination.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(destination.description),
          const SizedBox(height: 16),
          Text('District: ${destination.district ?? 'Unknown'}'),
          Text('Type: ${destination.type}'),
          Text('Price Tier: ${destination.priceTier}'),
          Text('Accessibility: ${destination.accessibility ?? 'N/A'}'),
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
                    '${accommodation.priceRange != null ? ' • ${accommodation.priceRange}' : ''}',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}