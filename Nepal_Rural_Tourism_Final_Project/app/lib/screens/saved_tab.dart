import 'package:flutter/material.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Places'),
      ),
      body: savedDestinations.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved destinations yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedDestinations.length,
              itemBuilder: (context, index) {
                final destination = savedDestinations[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      DestinationCard(
                        destination: destination,
                        reasons: const ['Saved destination'],
                        scoreLabel: 'Saved',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                destination: destination,
                                nearbyAccommodations: accommodations,
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton.filledTonal(
                          onPressed: () async {
                            await onToggleSaved(destination);
                          },
                          icon: const Icon(Icons.bookmark),
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