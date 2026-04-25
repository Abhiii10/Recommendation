import 'dart:math';

/// Haversine formula — returns the great-circle distance in **kilometres**
/// between two WGS-84 coordinates.
///
/// Used for:
///   • Itinerary travel-time estimates (Feature 5).
///   • Geographic proximity in itinerary day-grouping (Feature 3).
///   • Distance-from-user display on the map (Feature 4).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _toRad(lat2 - lat1);
  final double dLon = _toRad(lon2 - lon1);

  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

/// Estimated travel time in **minutes** between two coordinates,
/// assuming 30 km/h average in mountain terrain.
int estimatedTravelMinutes(
  double lat1,
  double lon1,
  double lat2,
  double lon2, {
  double avgSpeedKmh = 30.0,
}) {
  final double distKm = haversineKm(lat1, lon1, lat2, lon2);
  return (distKm / avgSpeedKmh * 60).round();
}

double _toRad(double deg) => deg * pi / 180;
