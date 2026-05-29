import 'package:latlong2/latlong.dart';

enum TravelMode {
  driving,
  walking,
  cycling,
}

extension TravelModeX on TravelMode {
  String get osrmPath => switch (this) {
        TravelMode.driving => 'driving',
        TravelMode.walking => 'walking',
        TravelMode.cycling => 'cycling',
      };

  String get label => switch (this) {
        TravelMode.driving => 'Drive',
        TravelMode.walking => 'Walk',
        TravelMode.cycling => 'Cycle',
      };
}

class RouteResult {
  final List<LatLng> polylinePoints;
  final List<RouteStep> steps;
  final double distanceMeters;
  final double durationSeconds;
  final TravelMode travelMode;

  const RouteResult({
    required this.polylinePoints,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
  });
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String maneuverDirection;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.maneuverDirection,
    required this.location,
  });
}
