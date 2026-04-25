import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/accommodation.dart';
import '../models/destination.dart';
import 'details_screen.dart';

class MapScreen extends StatelessWidget {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;

  const MapScreen({
    super.key,
    required this.destinations,
    required this.accommodations,
  });

  @override
  Widget build(BuildContext context) {
    final mappedDestinations = destinations
        .where((d) => d.latitude != null && d.longitude != null)
        .toList();

    final center = mappedDestinations.isNotEmpty
        ? LatLng(
            mappedDestinations.first.latitude!,
            mappedDestinations.first.longitude!,
          )
        : const LatLng(28.2096, 83.9856); // Pokhara fallback

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination Map'),
      ),
      body: mappedDestinations.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No destination coordinates available in the dataset.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rural_tourism_app',
                ),
                MarkerLayer(
                  markers: mappedDestinations.map((destination) {
                    return Marker(
                      point: LatLng(
                        destination.latitude!,
                        destination.longitude!,
                      ),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                destination: destination,
                                nearbyAccommodations: accommodations, // ✅ FIXED
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          size: 36,
                          color: Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}