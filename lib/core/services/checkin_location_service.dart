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

  static const double allowedDistanceMeters = 100;

  Future<CheckInLocationResult> verify({
    required double latitude,
    required double longitude,
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );
      return distance <= allowedDistanceMeters
          ? CheckInLocationResult.verified
          : CheckInLocationResult.tooFar;
    } catch (error, stackTrace) {
      debugPrint(
        'CheckInLocationService.verify failed: $error\n$stackTrace',
      );
      return CheckInLocationResult.unavailable;
    }
  }
}
