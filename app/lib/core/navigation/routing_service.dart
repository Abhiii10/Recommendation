// OSRM public demo server is free but has rate limits.
// For production at scale, self-host OSRM or switch to:
//   - OpenRouteService (free tier: 2000 req/day)
//   - Valhalla (fully open source, self-hostable)
//   - GraphHopper (free tier available)
// No API key is required for the current implementation.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models/route_result.dart';

class RoutingService {
  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  Future<RouteResult?> getRoute(
    LatLng origin,
    LatLng destination, {
    TravelMode travelMode = TravelMode.driving,
  }) async {
    try {
      final uri = Uri.parse(
        'http://router.project-osrm.org/route/v1/${travelMode.osrmPath}/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true&annotations=false',
      );

      final response = await _client.get(uri).timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.isEmpty) return null;

      final points = coordinates
          .map((coordinate) {
            final pair = coordinate as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .where((point) => point.latitude.isFinite && point.longitude.isFinite)
          .toList(growable: false);

      if (points.isEmpty) return null;

      final steps = <RouteStep>[];
      final legs = route['legs'] as List<dynamic>? ?? const [];
      for (final leg in legs) {
        final legSteps =
            (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ??
                const [];
        for (final rawStep in legSteps) {
          final step = rawStep as Map<String, dynamic>;
          final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
          final location = maneuver['location'] as List<dynamic>?;
          if (location == null || location.length < 2) continue;

          final type = (maneuver['type'] as String?) ?? '';
          final modifier = (maneuver['modifier'] as String?) ?? '';
          final name = (step['name'] as String?)?.trim() ?? '';

          steps.add(
            RouteStep(
              instruction: _instructionFor(type, modifier, name),
              distanceMeters: ((step['distance'] as num?) ?? 0).toDouble(),
              durationSeconds: ((step['duration'] as num?) ?? 0).toDouble(),
              maneuverType: type,
              maneuverDirection: modifier,
              location: LatLng(
                (location[1] as num).toDouble(),
                (location[0] as num).toDouble(),
              ),
            ),
          );
        }
      }

      return RouteResult(
        polylinePoints: points,
        steps: steps,
        distanceMeters: ((route['distance'] as num?) ?? 0).toDouble(),
        durationSeconds: ((route['duration'] as num?) ?? 0).toDouble(),
        travelMode: travelMode,
      );
    } catch (_) {
      return null;
    }
  }

  String _instructionFor(String type, String modifier, String name) {
    final direction = _readableDirection(modifier);
    final road = name.isEmpty ? '' : ' onto $name';

    return switch (type) {
      'depart' => 'Head ${direction.isEmpty ? 'straight' : direction}$road',
      'arrive' => 'Arrive at destination',
      'turn' => 'Turn ${direction.isEmpty ? 'ahead' : direction}$road',
      'new name' => 'Continue$road',
      'continue' =>
        'Continue ${direction.isEmpty ? 'straight' : direction}$road',
      'merge' => 'Merge ${direction.isEmpty ? 'ahead' : direction}$road',
      'on ramp' => 'Take the ramp$road',
      'off ramp' => 'Take the exit$road',
      'fork' => 'Keep ${direction.isEmpty ? 'ahead' : direction}$road',
      'end of road' =>
        'At the end of the road, go ${direction.isEmpty ? 'ahead' : direction}$road',
      'roundabout' || 'rotary' => 'Enter the roundabout$road',
      'roundabout turn' =>
        'At the roundabout, turn ${direction.isEmpty ? 'ahead' : direction}$road',
      'notification' => 'Continue$road',
      _ => 'Continue ${direction.isEmpty ? 'ahead' : direction}$road',
    };
  }

  String _readableDirection(String modifier) {
    return switch (modifier) {
      'uturn' => 'around',
      'sharp right' => 'sharp right',
      'right' => 'right',
      'slight right' => 'slight right',
      'straight' => 'straight',
      'slight left' => 'slight left',
      'left' => 'left',
      'sharp left' => 'sharp left',
      _ => '',
    };
  }
}
