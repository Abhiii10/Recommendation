import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<Position?> currentPosition(BuildContext context) async {
    final allowed = await _ensurePermission(context);
    if (!allowed) return null;

    try {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location.')),
        );
      }
      return null;
    }
  }

  Future<Stream<Position>?> positionStream(BuildContext context) async {
    final allowed = await _ensurePermission(context);
    if (!allowed) return null;

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  Future<bool> _ensurePermission(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission needed for navigation'),
          ),
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission needed for navigation'),
          ),
        );
      }
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }
}
