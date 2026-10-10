import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/geofencing_service.dart';
import '../data/models/geofence_alert.dart';

class GeofenceProvider extends ChangeNotifier {
  static const _kKey = 'geofence_alerts_v1';
  static const _monitoringKey = 'geofence_monitoring_opted_in_v1';
  final List<GeofenceAlert> _alerts = [];
  bool _monitoring = false;
  GeofencingStartResult? _lastStartResult;

  List<GeofenceAlert> get alerts => List.unmodifiable(_alerts);
  bool get isMonitoring => _monitoring;
  GeofencingStartResult? get lastStartResult => _lastStartResult;

  GeofenceProvider() {
    _load();
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
    notifyListeners();
    await GeofencingService.instance.setAlerts(_alerts);
    if (monitoringWasEnabled && _alerts.any((alert) => alert.enabled)) {
      _lastStartResult = await GeofencingService.instance.startMonitoring(
        _alerts,
        requestPermissions: false,
      );
      _monitoring = _lastStartResult == GeofencingStartResult.started;
      if (!_monitoring) {
        await prefs.setBool(_monitoringKey, false);
      }
      notifyListeners();
    } else if (monitoringWasEnabled) {
      await prefs.setBool(_monitoringKey, false);
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
    _alerts.removeWhere((a) => a.placeId == placeId);
    await _save();
    await _syncAlerts();
    notifyListeners();
  }

  Future<void> updateRadius(String placeId, int radius) async {
    final i = _alerts.indexWhere((a) => a.placeId == placeId);
    if (i == -1) return;
    _alerts[i] = _alerts[i].copyWith(radiusMeters: radius);
    await _save();
    await _syncAlerts();
    notifyListeners();
  }

  Future<GeofencingStartResult> startMonitoring() async {
    _lastStartResult = await GeofencingService.instance.startMonitoring(
      _alerts,
    );
    _monitoring = _lastStartResult == GeofencingStartResult.started;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, _monitoring);
    notifyListeners();
    return _lastStartResult!;
  }

  Future<void> stopMonitoring() async {
    await GeofencingService.instance.stop();
    _monitoring = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, false);
    notifyListeners();
  }

  Future<void> _syncAlerts() async {
    await GeofencingService.instance.setAlerts(_alerts);
    _monitoring = GeofencingService.instance.isMonitoring;
    if (!_monitoring) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_monitoringKey, false);
    }
  }
}
