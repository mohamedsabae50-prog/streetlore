import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/gamification_stats.dart';
import '../core/services/supabase_service.dart';
import 'auth_provider.dart';

class GamificationProvider extends ChangeNotifier {
  GamificationStats _stats = GamificationStats(
    userId: 'me',
    userName: 'You',
    avatarColorHex: '0xFF3B82F6',
  );
  GamificationStats get stats => _stats;

  static const _kKey = 'gamification_stats_v1';

  GamificationProvider() {
    _load();
  }

  void syncWithAuth(AuthProvider auth) {
    if (auth.userId.isEmpty) return;
    if (_stats.userId == auth.userId &&
        _stats.userName == auth.userName) {
      return;
    }
    setUserIdentity(
      userId: auth.userId,
      userName: auth.userName.isEmpty ? 'Explorer' : auth.userName,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _stats = GamificationStats.fromJson(json);
    } catch (e) {
      debugPrint('GamificationProvider: failed to load: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_stats.toJson()));

    SupabaseService.instance.pushStats(_stats);
  }

  Future<Badge?> applyAction(String action) async {
    final pts = GamificationStats.pointsFor(action);
    if (pts == 0) return null;

    final newPoints = _stats.totalPoints + pts;
    final newLevel = GamificationStats.levelForPoints(newPoints);
    final prevLevel = _stats.level;

    final updatedBadges = List<Badge>.from(_stats.badges);
    final justEarned = _maybeUnlockBadge(action, newPoints);
    if (justEarned != null) updatedBadges.add(justEarned);

    _stats = _stats.copyWith(
      totalPoints: newPoints,
      level: newLevel,
      placesVisited: action == 'check_in'
          ? _stats.placesVisited + 1
          : _stats.placesVisited,
      reviewsPosted: action == 'review'
          ? _stats.reviewsPosted + 1
          : _stats.reviewsPosted,
      photosUploaded: action == 'photo'
          ? _stats.photosUploaded + 1
          : _stats.photosUploaded,
      badges: updatedBadges,
    );

    await _save();
    notifyListeners();

    if (justEarned != null) return justEarned;
    if (newLevel != prevLevel) return _levelBadge(newLevel);
    return null;
  }

  Badge? _maybeUnlockBadge(String action, int totalPoints) {
    const id = 'b_checkin_first';
    final alreadyHas = _stats.badges.any((b) => b.id == id);
    if (action == 'check_in' && !alreadyHas) {
      return Badge(
        id: id,
        name: 'First Steps',
        description: 'Checked in at your first Streetlore place',
        iconName: 'explore',
        tier: 'bronze',
        earnedAt: DateTime.now(),
        pointsAwarded: 10,
      );
    }
    return null;
  }

  Badge? _levelBadge(String level) {
    return Badge(
      id: 'lvl_$level',
      name: '$level rank',
      description: 'Reached the $level tier',
      iconName: 'military_tech',
      tier: 'silver',
      earnedAt: DateTime.now(),
      pointsAwarded: 25,
    );
  }

  static const List<int> streakMilestones = [5, 10, 25, 50];

  Future<Badge?> checkStreakMilestone(int streak) async {
    if (!streakMilestones.contains(streak)) return null;
    final id = 'b_streak_$streak';
    if (_stats.badges.any((b) => b.id == id)) return null;

    final badge = Badge(
      id: id,
      name: 'badge_streak_$streak',
      description: 'Visited $streak places',
      iconName: 'local_fire_department',
      tier: streak >= 25 ? 'gold' : 'silver',
      earnedAt: DateTime.now(),
      pointsAwarded: 0,
    );
    _stats = _stats.copyWith(badges: [..._stats.badges, badge]);
    await _save();
    notifyListeners();
    return badge;
  }

  Future<void> addBadgeIfMissing(Badge badge) async {
    if (_stats.badges.any((b) => b.id == badge.id)) return;
    _stats = _stats.copyWith(
      badges: [..._stats.badges, badge],
      totalPoints: _stats.totalPoints + badge.pointsAwarded,
      level: GamificationStats.levelForPoints(
          _stats.totalPoints + badge.pointsAwarded),
    );
    await _save();
    notifyListeners();
  }

  void setUserIdentity({
    required String userId,
    required String userName,
    String? avatarColorHex,
  }) {
    _stats = GamificationStats(
      userId: userId,
      userName: userName,
      avatarColorHex: avatarColorHex ?? _stats.avatarColorHex,
      totalPoints: _stats.totalPoints,
      placesVisited: _stats.placesVisited,
      reviewsPosted: _stats.reviewsPosted,
      photosUploaded: _stats.photosUploaded,
      badges: _stats.badges,
      level: _stats.level,
    );
    _save();
    notifyListeners();
  }

  void reset() {
    _stats = GamificationStats(
      userId: _stats.userId,
      userName: _stats.userName,
      avatarColorHex: _stats.avatarColorHex,
    );
    _save();
    notifyListeners();
  }
}
