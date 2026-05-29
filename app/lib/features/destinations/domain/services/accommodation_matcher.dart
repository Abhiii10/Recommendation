import 'package:rural_tourism_app/features/destinations/domain/models/accommodation.dart';
import 'package:rural_tourism_app/features/destinations/domain/models/destination.dart';

List<Accommodation> accommodationsForDestination(
  Destination destination,
  List<Accommodation> accommodations,
) {
  return accommodations.where((accommodation) {
    final matchesId = accommodation.destinationId == destination.id;
    final matchesName = _normalize(accommodation.destinationName) ==
        _normalize(destination.name);
    return matchesId || matchesName;
  }).toList();
}

String _normalize(String value) => value.trim().toLowerCase();
