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

class CheckInLocationService {
  CheckInLocationService._();
  static final CheckInLocationService instance = CheckInLocationService._();

  Future<CheckInLocationResult> verify({
    required double latitude,
    required double longitude,
    required double allowedDistanceMeters,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return CheckInLocationResult.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return CheckInLocationResult.permissionDenied;
      }

      final cachedPosition = await Geolocator.getLastKnownPosition();
      if (cachedPosition != null &&
          _isWithinRadius(
            cachedPosition,
            latitude,
            longitude,
            allowedDistanceMeters,
          )) {
        return CheckInLocationResult.verified;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );
      return _isWithinRadius(
            position,
            latitude,
            longitude,
            allowedDistanceMeters,
          )
          ? CheckInLocationResult.verified
          : CheckInLocationResult.tooFar;
    } catch (error, stackTrace) {
      debugPrint('CheckInLocationService.verify failed: $error\n$stackTrace');
      return CheckInLocationResult.unavailable;
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
