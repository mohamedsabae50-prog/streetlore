import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/governorate_service.dart';
import '../data/models/egypt_governorate.dart';

class GovernorateProvider extends ChangeNotifier {
  static const _activeKey = 'active_governorate';
  static const _unlockedKey = 'unlocked_governorates';
  static const _fogEnabledKey = 'governorate_fog_enabled';
  static const _activeGovernorateIds = [
    'alexandria',
    'cairo',
    'luxor',
    'red_sea',
  ];

  String _activeGovernorate = 'alexandria';
  String _detectedGovernorate = 'alexandria';
  Set<String> _unlockedGovernorateIds = {'alexandria'};
  bool _fogEnabled = true;
  String? _pendingNoticeGovernorateId;
  final Set<String> _notifiedUnavailableGovernorates = {};
  late final Future<void> _preferencesReady;

  String get activeGovernorate => _activeGovernorate;
  String get detectedGovernorate => _detectedGovernorate;
  Set<String> get unlockedGovernorateIds =>
      Set.unmodifiable(_unlockedGovernorateIds);
  bool get fogEnabled => _fogEnabled;

  GovernorateProvider() {
    _preferencesReady = _loadPreferences().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Governorate preferences load failed: $error\n$stackTrace');
    });
    unawaited(
      detectAndSelectUserGovernorate().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Governorate GPS detection failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> detectAndSelectUserGovernorate() async {
    await _preferencesReady;
    if (kIsWeb) return;

    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return;

    final position =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 5),
        );
    final lat = position.latitude;
    final lng = position.longitude;
    if (!_isWithinEgypt(lat, lng)) return;

    EgyptGovernorate? containingGovernorate;
    for (final id in _activeGovernorateIds) {
      final governorate = EgyptGovernorate.byId[id]!;
      if (GovernorateService.containsCoordinates(governorate, lat, lng)) {
        containingGovernorate = governorate;
        break;
      }
    }
    final selectedGovernorate =
        containingGovernorate ??
        _nearestActiveGovernorate(lat, lng, _activeGovernorateIds.toSet())!;

    final id = selectedGovernorate.id;
    final stateChanged =
        _activeGovernorate != id ||
        _detectedGovernorate != id ||
        !_unlockedGovernorateIds.contains(id);
    _activeGovernorate = id;
    _detectedGovernorate = id;
    _unlockedGovernorateIds.add(id);
    if (stateChanged) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final active = preferences.getString(_activeKey);
    final unlocked = preferences.getStringList(_unlockedKey);
    final fogEnabled = preferences.getBool(_fogEnabledKey);
    var changed = false;
    final normalizedActive = active == null
        ? null
        : EgyptGovernorate.normalizeId(active);
    if (normalizedActive != null &&
        EgyptGovernorate.byId.containsKey(normalizedActive)) {
      _activeGovernorate = normalizedActive;
      changed = true;
    }
    if (unlocked != null) {
      _unlockedGovernorateIds = {
        'alexandria',
        ...unlocked
            .map(EgyptGovernorate.normalizeId)
            .where(EgyptGovernorate.byId.containsKey),
      };
      changed = true;
    }
    if (fogEnabled != null) {
      _fogEnabled = fogEnabled;
      changed = true;
    }
    if (_unlockedGovernorateIds.add(_activeGovernorate)) changed = true;
    if (changed) notifyListeners();
  }

  Future<void> syncWithCoordinates(
    double lat,
    double lng, {
    required Set<String> availableGovernorateIds,
  }) async {
    await _preferencesReady;
    final detected = EgyptGovernorate.normalizeId(
      GovernorateService.detectFromCoordinates(lat, lng).id,
    );
    availableGovernorateIds = availableGovernorateIds
        .map(EgyptGovernorate.normalizeId)
        .toSet();
    final previousActive = _activeGovernorate;
    final previousDetected = _detectedGovernorate;
    final previousUnlockedCount = _unlockedGovernorateIds.length;
    final previousNotice = _pendingNoticeGovernorateId;
    _detectedGovernorate = detected;

    if (availableGovernorateIds.contains(detected)) {
      _activeGovernorate = detected;
      _unlockedGovernorateIds.add(detected);
      _notifiedUnavailableGovernorates.remove(detected);
      _pendingNoticeGovernorateId = null;
    } else {
      final nearestAvailable = _isWithinEgypt(lat, lng)
          ? _nearestActiveGovernorate(lat, lng, availableGovernorateIds.toSet())
          : null;
      _activeGovernorate = nearestAvailable?.id ?? 'alexandria';
      if (nearestAvailable != null) {
        _unlockedGovernorateIds.add(nearestAvailable.id);
      }
      if (_notifiedUnavailableGovernorates.add(detected)) {
        _pendingNoticeGovernorateId = detected;
      }
    }

    final stateChanged =
        previousActive != _activeGovernorate ||
        previousDetected != _detectedGovernorate ||
        previousUnlockedCount != _unlockedGovernorateIds.length;
    if (stateChanged) await _persist();
    if (stateChanged || previousNotice != _pendingNoticeGovernorateId) {
      notifyListeners();
    }
  }

  static bool _isWithinEgypt(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= 21.7 &&
      lat <= 31.9 &&
      lng >= 24.5 &&
      lng <= 37.0;

  static EgyptGovernorate? _nearestActiveGovernorate(
    double lat,
    double lng,
    Set<String> availableGovernorateIds,
  ) {
    final candidates = _activeGovernorateIds
        .where(availableGovernorateIds.contains)
        .map((id) => EgyptGovernorate.byId[id]!)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    return candidates.reduce((nearest, candidate) {
      final nearestDistance = Geolocator.distanceBetween(
        lat,
        lng,
        nearest.centerLat,
        nearest.centerLng,
      );
      final candidateDistance = Geolocator.distanceBetween(
        lat,
        lng,
        candidate.centerLat,
        candidate.centerLng,
      );
      return candidateDistance < nearestDistance ? candidate : nearest;
    });
  }

  bool setActiveGovernorate(String id) {
    final normalizedId = EgyptGovernorate.normalizeId(id);
    if (!EgyptGovernorate.byId.containsKey(normalizedId) ||
        !_unlockedGovernorateIds.contains(normalizedId)) {
      return false;
    }
    if (_activeGovernorate == normalizedId) return true;
    _activeGovernorate = normalizedId;
    _persistSafely();
    notifyListeners();
    return true;
  }

  bool unlockAndSelectGovernorate(String id) {
    final normalizedId = EgyptGovernorate.normalizeId(id);
    if (!EgyptGovernorate.byId.containsKey(normalizedId)) return false;
    final changed =
        _unlockedGovernorateIds.add(normalizedId) ||
        _activeGovernorate != normalizedId;
    _activeGovernorate = normalizedId;
    if (changed) {
      _persistSafely();
      notifyListeners();
    }
    return true;
  }

  void setFogEnabled(bool enabled) {
    if (_fogEnabled == enabled) return;
    _fogEnabled = enabled;
    _persistSafely();
    notifyListeners();
  }

  void _persistSafely() {
    _persist().catchError((Object error, StackTrace stackTrace) {
      debugPrint('Governorate preferences save failed: $error\n$stackTrace');
    });
  }

  String? takeNoticeMessage(String languageCode) {
    final id = _pendingNoticeGovernorateId;
    if (id == null) return null;
    _pendingNoticeGovernorateId = null;
    final governorate = EgyptGovernorate.byId[id]!;
    if (languageCode == 'ar') {
      return '📍 موقعك الحالي: محافظة ${governorate.nameAr} '
          '(قريباً تحت الضباب 🔒) — تتوفر الآن خرائط الإسكندرية والقاهرة والجيزة والأقصر وأسوان';
    }
    return '📍 Your current location: ${governorate.nameEn} Governorate '
        '(coming soon under fog 🔒) — Alexandria, Cairo & Giza, and Luxor & Aswan are available now';
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeKey, _activeGovernorate);
    await preferences.setStringList(
      _unlockedKey,
      _unlockedGovernorateIds.toList(growable: false),
    );
    await preferences.setBool(_fogEnabledKey, _fogEnabled);
  }
}
