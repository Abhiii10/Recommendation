import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rural_tourism_app/core/observability/app_telemetry.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';
import 'package:rural_tourism_app/core/data/offline_storage.dart';

final telemetryProvider = Provider<AppTelemetry>((ref) {
  return AppTelemetry.instance;
});

final destinationsProvider = FutureProvider<List<Destination>>((ref) {
  return OfflineStorage.loadDestinations();
});

final accommodationsProvider = FutureProvider<List<Accommodation>>((ref) {
  return OfflineStorage.loadAccommodations();
});

final appCatalogProvider = FutureProvider<AppCatalog>((ref) async {
  final destinations = await ref.watch(destinationsProvider.future);
  final accommodations = await ref.watch(accommodationsProvider.future);
  final similarPlaces = await OfflineStorage.loadSimilarPlaces();

  return AppCatalog(
    destinations: destinations,
    accommodations: accommodations,
    similarPlaces: similarPlaces,
  );
});

class AppCatalog {
  final List<Destination> destinations;
  final List<Accommodation> accommodations;
  final Map<String, List<Map<String, dynamic>>> similarPlaces;

  const AppCatalog({
    required this.destinations,
    required this.accommodations,
    required this.similarPlaces,
  });
}
