import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/geofencing_service.dart';
import '../data/models/geofence_alert.dart';
import '../data/models/place_model.dart';

class GeofenceProvider extends ChangeNotifier {
  static const _kKey = 'geofence_alerts_v1';
  static const _monitoringKey = 'geofence_monitoring_opted_in_v1';
  static const _smartAlertsKey = 'smart_location_alerts_enabled_v1';
  final List<GeofenceAlert> _alerts = [];
  late final Future<void> _loadFuture;
  bool _monitoring = false;
  bool _smartAlertsEnabled = false;
  GeofencingStartResult? _lastStartResult;

  List<GeofenceAlert> get alerts => List.unmodifiable(_alerts);
  bool get isMonitoring => _monitoring;
  bool get smartAlertsEnabled => _smartAlertsEnabled;
  Future<void> get ready => _loadFuture;
  GeofencingStartResult? get lastStartResult => _lastStartResult;

  GeofenceProvider() {
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const [];
    _alerts
      ..clear()
      ..addAll(
        raw.map(
          (s) => GeofenceAlert.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map),
          ),
        ),
      );
    final monitoringWasEnabled = prefs.getBool(_monitoringKey) ?? false;
    final smartAlertsWereEnabled = prefs.getBool(_smartAlertsKey) ?? false;
    notifyListeners();
    await GeofencingService.instance.setAlerts(_alerts);
    if (monitoringWasEnabled && _alerts.any((alert) => alert.enabled)) {
      _lastStartResult = await GeofencingService.instance.startMonitoring(
        _alerts,
        requestPermissions: false,
      );
      _monitoring = _lastStartResult == GeofencingStartResult.started;
      _smartAlertsEnabled = _monitoring && smartAlertsWereEnabled;
      if (!_monitoring) {
        await prefs.setBool(_monitoringKey, false);
        await prefs.setBool(_smartAlertsKey, false);
      }
      notifyListeners();
    } else if (monitoringWasEnabled) {
      await prefs.setBool(_monitoringKey, false);
      await prefs.setBool(_smartAlertsKey, false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kKey,
      _alerts.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> toggle(GeofenceAlert alert) async {
    await _loadFuture;
    final i = _alerts.indexWhere((a) => a.placeId == alert.placeId);
    if (i == -1) {
      _alerts.add(alert);
    } else {
      _alerts[i] = _alerts[i].copyWith(enabled: !_alerts[i].enabled);
    }
    await _save();
    await _syncAlerts();
    notifyListeners();
  }

  Future<void> remove(String placeId) async {
    await _loadFuture;
    _alerts.removeWhere((a) => a.placeId == placeId);
    await _save();
    await _syncAlerts();
    notifyListeners();
  }

  Future<void> updateRadius(String placeId, int radius) async {
    await _loadFuture;
    final i = _alerts.indexWhere((a) => a.placeId == placeId);
    if (i == -1) return;
    _alerts[i] = _alerts[i].copyWith(radiusMeters: radius);
    await _save();
    await _syncAlerts();
    notifyListeners();
  }

  Future<GeofencingStartResult> startMonitoring() async {
    await _loadFuture;
    _lastStartResult = await GeofencingService.instance.startMonitoring(
      _alerts,
    );
    _monitoring = _lastStartResult == GeofencingStartResult.started;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, _monitoring);
    if (!_monitoring) {
      _smartAlertsEnabled = false;
      await prefs.setBool(_smartAlertsKey, false);
    }
    notifyListeners();
    return _lastStartResult!;
  }

  Future<void> stopMonitoring() async {
    await _loadFuture;
    await GeofencingService.instance.stop();
    _monitoring = false;
    _smartAlertsEnabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, false);
    await prefs.setBool(_smartAlertsKey, false);
    notifyListeners();
  }

  Future<GeofencingStartResult> enableSmartAlerts(
    List<PlaceModel> places,
  ) async {
    await _loadFuture;
    final hiddenGems = places
        .where(
          (place) =>
              place.isHiddenGem &&
              place.lat.isFinite &&
              place.lng.isFinite &&
              place.lat >= -90 &&
              place.lat <= 90 &&
              place.lng >= -180 &&
              place.lng <= 180,
        )
        .toList(growable: false);
    if (hiddenGems.isEmpty) {
      _lastStartResult = GeofencingStartResult.noPlacesSelected;
      notifyListeners();
      return _lastStartResult!;
    }

    final existing = {for (final alert in _alerts) alert.placeId: alert};
    final hiddenGemIds = hiddenGems.map((place) => place.id).toSet();
    final retainedAlerts = existing.values
        .where(
          (alert) =>
              !hiddenGemIds.contains(alert.placeId) &&
              (!alert.isSmartAlert || alert.isUserConfigured),
        )
        .map(
          (alert) =>
              alert.isSmartAlert ? alert.copyWith(isSmartAlert: false) : alert,
        )
        .toList(growable: false);
    _alerts
      ..clear()
      ..addAll(retainedAlerts)
      ..addAll(
        hiddenGems.map((place) {
          final saved = existing[place.id];
          return GeofenceAlert(
            placeId: place.id,
            placeName: place.localizedName('en'),
            lat: place.lat,
            lng: place.lng,
            radiusMeters: 150,
            isSmartAlert: true,
            isUserConfigured: saved?.isUserConfigured ?? false,
            lastTriggeredAt: saved?.lastTriggeredAt,
          );
        }),
      );
    await _save();
    final result = await startMonitoring();
    _smartAlertsEnabled = result == GeofencingStartResult.started;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartAlertsKey, _smartAlertsEnabled);
    notifyListeners();
    return result;
  }

  Future<void> disableSmartAlerts() async {
    await _loadFuture;
    final remainingAlerts = _alerts
        .where((alert) => !alert.isSmartAlert || alert.isUserConfigured)
        .map(
          (alert) =>
              alert.isSmartAlert ? alert.copyWith(isSmartAlert: false) : alert,
        )
        .toList(growable: false);
    _alerts
      ..clear()
      ..addAll(remainingAlerts);
    _smartAlertsEnabled = false;
    await _save();
    await _syncAlerts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smartAlertsKey, false);
    notifyListeners();
  }

  Future<void> _syncAlerts() async {
    await GeofencingService.instance.setAlerts(_alerts);
    _monitoring = GeofencingService.instance.isMonitoring;
    if (!_monitoring) {
      _smartAlertsEnabled = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_monitoringKey, false);
      await prefs.setBool(_smartAlertsKey, false);
    }
    notifyListeners();
  }
}
