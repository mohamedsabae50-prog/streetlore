import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/geofence_alert.dart';

class GeofencingService {
  static const _lastFiredKey = 'geofence_last_fired_at_v1';
  static const _notificationCooldown = Duration(hours: 24);

  GeofencingService._();
  static final GeofencingService instance = GeofencingService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<Position>? _positionSub;
  final List<GeofenceAlert> _alerts = [];
  final Set<String> _insidePlaceIds = {};
  final Map<String, DateTime> _lastFiredAt = {};
  bool _initialised = false;
  bool _cooldownsLoaded = false;

  bool get isMonitoring => _positionSub != null;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    try {
      await _notifications.initialize(initSettings);
      _initialised = true;
    } catch (e) {
      debugPrint('GeofencingService: notifications init failed: $e');
    }
  }

  Future<void> _loadCooldowns() async {
    if (_cooldownsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastFiredKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is String) {
              final firedAt = DateTime.tryParse(value);
              if (firedAt != null) _lastFiredAt[entry.key] = firedAt;
            }
          }
        }
      } catch (error) {
        debugPrint(
          'GeofencingService: invalid notification cooldown cache: $error',
        );
      }
    }
    _cooldownsLoaded = true;
  }

  Future<GeofencingStartResult> _ensurePermissions({
    required bool requestPermissions,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return GeofencingStartResult.unsupported;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return GeofencingStartResult.locationServicesDisabled;
    }

    var foreground = await Permission.locationWhenInUse.status;
    if (!foreground.isGranted && requestPermissions) {
      foreground = await Permission.locationWhenInUse.request();
    }
    if (!foreground.isGranted) {
      return GeofencingStartResult.locationPermissionDenied;
    }

    var background = await Permission.locationAlways.status;
    if (!background.isGranted && requestPermissions) {
      background = await Permission.locationAlways.request();
    }
    if (!background.isGranted) {
      return GeofencingStartResult.backgroundPermissionDenied;
    }

    await _ensureInit();
    if (!_initialised) return GeofencingStartResult.notificationsUnavailable;
    final notificationsGranted = requestPermissions
        ? await _requestNotificationPermission()
        : (await Permission.notification.status).isGranted;
    if (!notificationsGranted) {
      return GeofencingStartResult.notificationPermissionDenied;
    }
    return GeofencingStartResult.started;
  }

  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<GeofencingStartResult> startMonitoring(
    List<GeofenceAlert> alerts, {
    bool requestPermissions = true,
  }) async {
    _alerts
      ..clear()
      ..addAll(alerts.where((a) => a.enabled));
    if (_alerts.isEmpty) {
      await stop();
      return GeofencingStartResult.noPlacesSelected;
    }
    if (_positionSub != null) {
      return GeofencingStartResult.started;
    }
    final permissionResult = await _ensurePermissions(
      requestPermissions: requestPermissions,
    );
    if (permissionResult != GeofencingStartResult.started) {
      debugPrint('GeofencingService: start denied: $permissionResult');
      return permissionResult;
    }
    try {
      await _loadCooldowns();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: _backgroundLocationSettings,
      ).listen(
        _onPosition,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('GeofencingService: position error: $error\n$stackTrace');
        },
      );
      return GeofencingStartResult.started;
    } catch (error, stackTrace) {
      debugPrint(
        'GeofencingService: could not start location stream: '
        '$error\n$stackTrace',
      );
      return GeofencingStartResult.locationUnavailable;
    }
  }

  LocationSettings get _backgroundLocationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 100,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Streetlore nearby stories',
          notificationText: 'Monitoring your selected nearby places.',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 100,
        pauseLocationUpdatesAutomatically: true,
        activityType: ActivityType.other,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: 100,
    );
  }

  Future<void> setAlerts(List<GeofenceAlert> alerts) async {
    _alerts
      ..clear()
      ..addAll(alerts.where((a) => a.enabled));
    if (_alerts.isEmpty) {
      await stop();
    }
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _insidePlaceIds.clear();
  }

  void _onPosition(Position pos) {
    for (final a in _alerts) {
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        a.lat,
        a.lng,
      );
      if (distance <= a.radiusMeters) {
        if (_insidePlaceIds.add(a.placeId)) {
          unawaited(_maybeFire(a));
        }
      } else if (distance > a.radiusMeters + 100) {
        _insidePlaceIds.remove(a.placeId);
      }
    }
  }

  Future<void> _maybeFire(GeofenceAlert a) async {
    final now = DateTime.now();
    final lastFire = _lastFiredAt[a.placeId];
    if (lastFire != null && now.difference(lastFire) < _notificationCooldown) {
      return;
    }
    _lastFiredAt[a.placeId] = now;
    if (!await _fireNotification(a)) {
      _lastFiredAt.remove(a.placeId);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastFiredKey,
        jsonEncode(
          _lastFiredAt.map(
            (placeId, firedAt) => MapEntry(placeId, firedAt.toIso8601String()),
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'GeofencingService: failed to persist notification cooldown: $error',
      );
    }
  }

  Future<bool> _fireNotification(GeofenceAlert a) async {
    try {
      await _notifications.show(
        a.placeId.hashCode,
        a.isSmartAlert ? 'Hidden gem nearby' : 'Nearby place',
        a.isSmartAlert
            ? 'You are near ${a.placeName}. Open Streetlore to discover it.'
            : 'You are near ${a.placeName}. Open Streetlore to discover its story.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streetlore_geofence',
            'Nearby places',
            channelDescription:
                'Alerts when you approach a saved or trending place',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('GeofencingService: notification fire failed: $e');
      return false;
    }
  }
}

enum GeofencingStartResult {
  started,
  noPlacesSelected,
  unsupported,
  locationServicesDisabled,
  locationPermissionDenied,
  backgroundPermissionDenied,
  notificationPermissionDenied,
  notificationsUnavailable,
  locationUnavailable,
}
