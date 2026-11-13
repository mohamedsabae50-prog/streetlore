import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/governorate_service.dart';
import '../data/models/egypt_governorate.dart';

class GovernorateProvider extends ChangeNotifier {
  static const _activeKey = 'active_governorate';
  static const _unlockedKey = 'unlocked_governorates';
  static const _fogEnabledKey = 'governorate_fog_enabled';

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
      _activeGovernorate = 'alexandria';
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
          '(قريباً تحت الضباب 🔒) — تتوفر الآن خرائط الإسكندرية والقاهرة';
    }
    return '📍 Your current location: ${governorate.nameEn} Governorate '
        '(coming soon under fog 🔒) — Alexandria and Cairo are available now';
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
