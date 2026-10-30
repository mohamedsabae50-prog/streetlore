import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/place_model.dart';
import '../data/achievement_catalog.dart';
import '../data/models/gamification_stats.dart';
import '../core/services/supabase_service.dart';
import 'auth_provider.dart';
import 'gamification_provider.dart';
import 'place_provider.dart';
import 'streak_provider.dart';
import 'tour_provider.dart';

class AchievementProgress {
  final String achievementId;
  final int current;
  final int target;
  final bool unlocked;
  final DateTime? unlockedAt;

  const AchievementProgress({
    required this.achievementId,
    required this.current,
    required this.target,
    required this.unlocked,
    this.unlockedAt,
  });

  double get ratio => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'achievement_id': achievementId,
    'current': current,
    'unlocked': unlocked,
    'unlocked_at': unlockedAt?.toIso8601String(),
  };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) =>
      AchievementProgress(
        achievementId: json['achievement_id'] as String,
        current: (json['current'] as num?)?.toInt() ?? 0,
        target: 0,
        unlocked: json['unlocked'] as bool? ?? false,
        unlockedAt: json['unlocked_at'] == null
            ? null
            : DateTime.parse(json['unlocked_at'] as String),
      );
}

class AchievementProvider extends ChangeNotifier {
  final AuthProvider auth;
  final GamificationProvider gam;
  final PlaceProvider places;
  final StreakProvider streak;
  final TourProvider tours;

  String _userKey = 'guest';
  Map<String, AchievementProgress> _progress = {};
  bool _initialized = false;
  int _loadGeneration = 0;
  int _friendCount = 0;
  int _friendCountGeneration = 0;
  static const _kPrefix = 'achievements_v2';
  String get _kKey => '${_kPrefix}_$_userKey';

  AchievementProvider({
    required this.auth,
    required this.gam,
    required this.places,
    required this.streak,
    required this.tours,
  }) {
    _userKey = _effectiveKey();
    unawaited(_load());
    places.addListener(_onSourceChanged);
    streak.addListener(_onSourceChanged);
    tours.addListener(_onSourceChanged);
    unawaited(refreshFriendCount());
  }

  @override
  void dispose() {
    places.removeListener(_onSourceChanged);
    streak.removeListener(_onSourceChanged);
    tours.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    if (_initialized) _recalculateAll();
  }

  String _effectiveKey() {
    final id = auth.userId;
    return id.isEmpty ? 'guest' : id;
  }

  void syncWithAuth(AuthProvider auth) {
    final newKey = auth.userId.isEmpty ? 'guest' : auth.userId;
    if (newKey == _userKey) return;
    _userKey = newKey;
    _initialized = false;
    _progress = {};
    unawaited(_load());
    unawaited(refreshFriendCount());
  }

  Future<void> refreshFriendCount() async {
    final generation = ++_friendCountGeneration;
    if (auth.userId.isEmpty) {
      _friendCount = 0;
      if (_initialized) _recalculateAll();
      return;
    }
    try {
      final friendships = await SupabaseService.instance.fetchFriendships();
      if (generation != _friendCountGeneration || auth.userId != _userKey) {
        return;
      }
      _friendCount = friendships
          .where((friendship) => friendship['status'] == 'accepted')
          .length;
      if (_initialized) _recalculateAll();
    } catch (error, stackTrace) {
      debugPrint(
        'AchievementProvider: failed to refresh friend count: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _load() async {
    final loadGeneration = ++_loadGeneration;
    final userKey = _userKey;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_kPrefix}_$userKey');
    final loaded = <String, AchievementProgress>{};
    try {
      if (raw != null) {
        for (final entry in raw.split('|')) {
          if (entry.isEmpty) continue;
          final parts = entry.split('::');
          if (parts.length < 2) continue;
          final id = parts[0];
          final cur = int.tryParse(parts[1]) ?? 0;
          final unlocked = parts.length > 2 && parts[2] == '1';
          final unlockedAt = parts.length > 3 && parts[3].isNotEmpty
              ? DateTime.tryParse(parts[3])
              : null;
          loaded[id] = AchievementProgress(
            achievementId: id,
            current: cur,
            target: 0,
            unlocked: unlocked,
            unlockedAt: unlockedAt,
          );
        }
      }
    } catch (e) {
      debugPrint('AchievementProvider: failed to load progress: $e');
    }
    if (loadGeneration != _loadGeneration || userKey != _userKey) return;
    _progress = loaded;
    _initialized = true;
    _recalculateAll();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _progress.entries
        .map((e) {
          final p = e.value;
          return '${p.achievementId}::${p.current}::${p.unlocked ? 1 : 0}::${p.unlockedAt?.toIso8601String() ?? ''}';
        })
        .join('|');
    await prefs.setString(_kKey, entries);
  }

  AchievementProgress progressFor(String id) {
    if (!_initialized || (auth.userId.isNotEmpty && !tours.checkInsLoaded)) {
      return AchievementProgress(
        achievementId: id,
        current: 0,
        target: AchievementCatalog.byId(id)?.target ?? 0,
        unlocked: false,
      );
    }
    return _progress[id] ??
        AchievementProgress(
          achievementId: id,
          current: 0,
          target: 0,
          unlocked: false,
        );
  }

  int get totalUnlocked {
    if (!_initialized || (auth.userId.isNotEmpty && !tours.checkInsLoaded)) {
      return 0;
    }
    return _progress.values.where((p) => p.unlocked).length;
  }

  int get totalAvailable => AchievementCatalog.all.length;
  double get completionRatio =>
      totalAvailable == 0 ? 0 : totalUnlocked / totalAvailable;

  int get totalPointsEarned {
    int sum = 0;
    for (final p in _progress.values) {
      if (!p.unlocked) continue;
      final def = AchievementCatalog.byId(p.achievementId);
      if (def != null) sum += def.points;
    }
    return sum;
  }

  List<AchievementDefinition> recentUnlocked({int limit = 3}) {
    if (!_initialized || (auth.userId.isNotEmpty && !tours.checkInsLoaded)) {
      return const <AchievementDefinition>[];
    }
    final entries =
        _progress.entries
            .where((e) => e.value.unlocked && e.value.unlockedAt != null)
            .toList()
          ..sort((a, b) => b.value.unlockedAt!.compareTo(a.value.unlockedAt!));
    return entries
        .take(limit)
        .map((e) => AchievementCatalog.byId(e.key))
        .whereType<AchievementDefinition>()
        .toList();
  }

  void _recalculateAll() {
    if (auth.userId.isNotEmpty && !tours.checkInsLoaded) return;

    final stats = gam.stats;
    final all = places.places;
    final streakDays = streak.currentStreak;
    final checkedInPlaceIds = tours.checkedInPlaceIds;
    final visitedCount = checkedInPlaceIds.length;
    final checkedInPlaces = all
        .where((place) => checkedInPlaceIds.contains(place.id))
        .toList(growable: false);
    final visitedTourCount = tours.visitedTourIds.length;
    gam.syncPlaceVisitCount(visitedCount);
    final hiddenGemsVisited = checkedInPlaces
        .where((place) => place.isHiddenGem)
        .length;

    for (final def in AchievementCatalog.all) {
      int cur = 0;
      if (def.id == 'squad_explorer') {
        cur = stats.badges.any((badge) => badge.id == def.id) ? def.target : 0;
      } else if (def.id == 'social_explorer') {
        cur = _friendCount;
      } else {
        switch (def.id) {
          case 'first_step':
          case 'explorer_5':
          case 'explorer_10':
          case 'explorer_25':
          case 'lorekeeper':
          case 'street_explorer':
          case 'lore_master':
          case 'alexandria_legend':
            cur = visitedCount;
            break;
          case 'culture_buff':
          case 'history_nerd':
          case 'time_traveler':
            cur = _countVisitedIn(checkedInPlaces, ['Historical']);
            if (def.id == 'culture_buff' || def.id == 'history_nerd') {
              cur += _countVisitedIn(checkedInPlaces, ['Culture']);
            }
            break;
          case 'foodie':
          case 'gourmet':
          case 'alex_foodie':
            cur = _countVisitedIn(checkedInPlaces, ['Food']);
            break;
          case 'nature_lover':
            cur = _countVisitedIn(checkedInPlaces, ['Nature']);
            break;
          case 'shopaholic':
            cur = _countVisitedIn(checkedInPlaces, ['Shopping']);
            break;
          case 'cafe_hopper':
            cur = _countVisitedIn(checkedInPlaces, ['Cafe']);
            break;
          case 'spiritual_seeker':
            cur = _countVisitedIn(checkedInPlaces, ['Mosques']);
            break;
          case 'pilgrim':
            cur = _countVisitedIn(checkedInPlaces, ['Churches']);
            break;
          case 'streak_3':
          case 'streak_7':
          case 'streak_30':
          case 'streak_100':
            cur = streakDays;
            break;
          case 'hidden_gem_hunter':
            cur = hiddenGemsVisited;
            break;
          case 'reviewer':
          case 'critic':
            cur = stats.reviewsPosted;
            break;
          case 'photographer':
          case 'influencer':
            cur = stats.photosUploaded;
            break;
          case 'early_bird':
          case 'night_owl':
            cur = visitedCount;
            break;
          case 'completionist':
          case 'tour_finisher':
          case 'grand_tour_master':
            cur = visitedTourCount;
            break;
          case 'community_spark':
            cur = stats.chatMessagesSent;
            break;
          case 'lens_of_alexandria':
            cur = stats.photosUploaded;
            break;
          case 'bookmark_collector':
            cur = places.savedPlacesCount;
            break;
        }
      }
      _updateProgress(def, cur);
    }
  }

  int _countVisitedIn(List<PlaceModel> checkedInPlaces, List<String> cats) {
    return checkedInPlaces
        .where((place) => cats.contains(place.category))
        .length;
  }

  double categoryProgress(String category) {
    final targets = <String, int>{
      'Historical': 5,
      'Food': 5,
      'Cafe': 4,
      'Shopping': 4,
      'Nature': 3,
      'Culture': 5,
    };
    final target = targets[category]!;
    final visitedIds = tours.checkedInPlaceIds;
    final count = places.places
        .where(
          (place) =>
              visitedIds.contains(place.id) && place.category == category,
        )
        .length;
    return (count / target).clamp(0.0, 1.0);
  }

  void _updateProgress(AchievementDefinition def, int current) {
    final previous = _progress[def.id];
    final wasUnlocked = previous?.unlocked ?? false;
    final wasCurrent = previous?.current ?? 0;
    final shouldUnlock = current >= def.target;
    final wasAt = previous?.unlockedAt;
    _progress[def.id] = AchievementProgress(
      achievementId: def.id,
      current: current,
      target: def.target,
      unlocked: shouldUnlock,
      unlockedAt: shouldUnlock ? (wasAt ?? DateTime.now()) : null,
    );
    if (!wasUnlocked &&
        shouldUnlock &&
        (def.id == 'tour_finisher' || def.id == 'grand_tour_master')) {
      unawaited(gam.recordActivity('tour_completed'));
    }
    final hasBadge = gam.stats.badges.any((badge) => badge.id == def.id);
    if (shouldUnlock && !hasBadge) {
      _grantBadge(def);
    } else if (!shouldUnlock && hasBadge) {
      // v1.0.63: revoke — the underlying stat dropped back below the
      // required target (e.g. user un-visited a place, placesVisited
      // went 1 → 0, first_steps' target of 1 is no longer met).
      _revokeBadge(def);
    }
    if (current != wasCurrent || shouldUnlock != wasUnlocked) {
      _save();
      notifyListeners();
    }
  }

  void _grantBadge(AchievementDefinition def) {
    gam.addBadgeIfMissing(
      Badge(
        id: def.id,
        name: def.nameKey,
        description: def.descKey,
        iconName: _iconName(def.icon),
        tier: _tierName(def.tier),
        earnedAt: DateTime.now(),
        pointsAwarded: def.points,
      ),
    );
  }

  void _revokeBadge(AchievementDefinition def) {
    gam.removeBadgeIfPresent(def.id);
  }

  String _iconName(IconData icon) {
    final code = icon.codePoint;
    return 'icon_$code';
  }

  String _tierName(AchievementTier tier) {
    return AchievementCatalog.tierName(tier).toLowerCase();
  }

  void refreshFromStats() {
    if (!_initialized) return;
    _recalculateAll();
    _save();
    notifyListeners();
  }
}
