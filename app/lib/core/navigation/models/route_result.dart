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
  final bool isFallback;

  const RouteResult({
    required this.polylinePoints,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
    this.isFallback = false,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      polylinePoints: _latLngListFromJson(json['polylinePoints']),
      steps: ((json['steps'] as List<dynamic>?) ?? const [])
          .map((step) => RouteStep.fromJson(Map<String, dynamic>.from(step)))
          .toList(growable: false),
      distanceMeters: ((json['distanceMeters'] as num?) ?? 0).toDouble(),
      durationSeconds: ((json['durationSeconds'] as num?) ?? 0).toDouble(),
      travelMode: _travelModeFromName(json['travelMode'] as String?),
      isFallback: (json['isFallback'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'polylinePoints': polylinePoints
          .map((point) => [point.latitude, point.longitude])
          .toList(growable: false),
      'steps': steps.map((step) => step.toJson()).toList(growable: false),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'travelMode': travelMode.name,
      'isFallback': isFallback,
    };
  }
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

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: (json['instruction'] as String?) ?? '',
      distanceMeters: ((json['distanceMeters'] as num?) ?? 0).toDouble(),
      durationSeconds: ((json['durationSeconds'] as num?) ?? 0).toDouble(),
      maneuverType: (json['maneuverType'] as String?) ?? '',
      maneuverDirection: (json['maneuverDirection'] as String?) ?? '',
      location: _latLngFromJson(json['location']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'maneuverType': maneuverType,
      'maneuverDirection': maneuverDirection,
      'location': [location.latitude, location.longitude],
    };
  }
}

List<LatLng> _latLngListFromJson(Object? value) {
  final points = value as List<dynamic>? ?? const [];
  return points
      .map(_latLngFromJson)
      .where((point) => point.latitude.isFinite && point.longitude.isFinite)
      .toList(growable: false);
}

LatLng _latLngFromJson(Object? value) {
  final pair = value as List<dynamic>? ?? const [0, 0];
  if (pair.length < 2) return const LatLng(0, 0);

  return LatLng(
    ((pair[0] as num?) ?? 0).toDouble(),
    ((pair[1] as num?) ?? 0).toDouble(),
  );
}

TravelMode _travelModeFromName(String? value) {
  return TravelMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => TravelMode.driving,
  );
}
