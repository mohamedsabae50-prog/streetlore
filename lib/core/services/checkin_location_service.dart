import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum CheckInLocationResult {
  verified,
  tooFar,
  permissionDenied,
  serviceDisabled,
  unavailable,
}

typedef CheckInLocationVerification = ({
  CheckInLocationResult result,
  Position? position,
});

class CheckInLocationService {
  CheckInLocationService._();
  static final CheckInLocationService instance = CheckInLocationService._();

  Future<CheckInLocationVerification> verify({
    required double latitude,
    required double longitude,
    required double allowedDistanceMeters,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (result: CheckInLocationResult.serviceDisabled, position: null);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return (result: CheckInLocationResult.permissionDenied, position: null);
      }

      final cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null &&
          _isWithinRadius(
            cachedPosition,
            latitude,
            longitude,
            allowedDistanceMeters,
          )) {
        return (
          result: CheckInLocationResult.verified,
          position: cachedPosition,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );
      final verified =
          _isWithinRadius(position, latitude, longitude, allowedDistanceMeters)
          ? CheckInLocationResult.verified
          : CheckInLocationResult.tooFar;
      return (
        result: verified,
        position: verified == CheckInLocationResult.verified ? position : null,
      );
    } catch (error, stackTrace) {
      debugPrint('CheckInLocationService.verify failed: $error\n$stackTrace');
      return (result: CheckInLocationResult.unavailable, position: null);
    }
  }

  static bool isWithinRadius({
    required double rawDistanceMeters,
    required double accuracyMeters,
    required double allowedDistanceMeters,
  }) {
    final accuracy = accuracyMeters.isFinite
        ? accuracyMeters.clamp(0.0, 80.0)
        : 0.0;
    return math.max(0.0, rawDistanceMeters - accuracy) <= allowedDistanceMeters;
  }

  bool _isWithinRadius(
    Position position,
    double latitude,
    double longitude,
    double allowedDistanceMeters,
  ) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
    return isWithinRadius(
      rawDistanceMeters: distance,
      accuracyMeters: position.accuracy,
      allowedDistanceMeters: allowedDistanceMeters,
    );
  }
}
