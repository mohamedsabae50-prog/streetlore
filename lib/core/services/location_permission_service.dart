import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized helper for the device-location permission flow.
///
/// On first launch (or whenever the user hasn't yet been asked) we call
/// [requestOnce] which:
///  * checks the current permission status,
///  * if not determined, prompts the OS dialog,
///  * persists the outcome so we don't nag the user on every launch.
///
/// On web, [requestOnce] is a no-op (browsers handle this themselves via
/// the Geolocation API).
class LocationPermissionService {
  LocationPermissionService._();
  static final LocationPermissionService instance = LocationPermissionService._();

  static const _kAskedKey = 'loc_perm_asked_v1';

  /// Returns the resulting status (granted, denied, deniedForever, etc).
  /// If the user has already been asked on this device, we still surface
  /// the current status without re-prompting.
  Future<LocationPermissionStatus> requestOnce() async {
    if (kIsWeb) return LocationPermissionStatus.granted;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kAskedKey) ?? false;

    // Make sure the underlying location service is on before we ask.
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

    // If we already asked and the user denied, don't keep pestering.
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

  /// True if location services are turned on at the OS level.
  Future<bool> isServiceEnabled() async {
    if (kIsWeb) return true;
    return Geolocator.isLocationServiceEnabled();
  }

  /// Open the OS settings page so the user can flip the permission on
  /// after a "permanently denied".
  Future<bool> openSettings() => openAppSettings();
}

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}
