import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPermissionService {
  LocationPermissionService._();
  static final LocationPermissionService instance = LocationPermissionService._();

  static const _kAskedKey = 'loc_perm_asked_v1';

  Future<LocationPermissionStatus> requestOnce() async {
    if (kIsWeb) return LocationPermissionStatus.granted;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kAskedKey) ?? false;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    final current = await Permission.locationWhenInUse.status;
    if (current.isGranted || current.isLimited) {
      return LocationPermissionStatus.granted;
    }
    if (current.isPermanentlyDenied) {
      return LocationPermissionStatus.permanentlyDenied;
    }

    if (alreadyAsked && current.isDenied) {
      return LocationPermissionStatus.denied;
    }

    final result = await Permission.locationWhenInUse.request();
    await prefs.setBool(_kAskedKey, true);
    if (result.isGranted || result.isLimited) {
      return LocationPermissionStatus.granted;
    }
    if (result.isPermanentlyDenied) {
      return LocationPermissionStatus.permanentlyDenied;
    }
    return LocationPermissionStatus.denied;
  }

  Future<bool> isServiceEnabled() async {
    if (kIsWeb) return true;
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> openSettings() => openAppSettings();
}

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}
