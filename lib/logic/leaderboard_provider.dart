import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../data/models/gamification_stats.dart';

class LeaderboardProvider extends ChangeNotifier {
  final SupabaseService _supa = SupabaseService.instance;
  List<GamificationStats> _entries = [];
  bool _loading = false;

  List<GamificationStats> get entries => List.unmodifiable(_entries);
  bool get isLoading => _loading;

  Future<void> load({int limit = 50}) async {
    _loading = true;
    notifyListeners();
    _entries = await _supa.fetchLeaderboard(limit: limit);
    if (_entries.isEmpty) {
      _entries = List.from(_mockLeaderboard);
    }
    _loading = false;
    notifyListeners();
  }

  void refreshWithUserStats(GamificationStats userStats) {
    _entries.removeWhere((e) => e.userId == userStats.userId);
    _entries.add(userStats);
    _entries.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    notifyListeners();
  }

  static const List<GamificationStats> _mockLeaderboard = [
    GamificationStats(userId: 'u1', userName: 'Ahmed H.', totalPoints: 1850, level: 'Lorekeeper'),
    GamificationStats(userId: 'u2', userName: 'Mahmoud S.', totalPoints: 1620, level: 'Cartographer'),
    GamificationStats(userId: 'u3', userName: 'Youssef M.', totalPoints: 1450, level: 'Cartographer'),
    GamificationStats(userId: 'u4', userName: 'Omar A.', totalPoints: 1200, level: 'Cartographer'),
    GamificationStats(userId: 'u5', userName: 'Tarek F.', totalPoints: 980, level: 'Wanderer'),
    GamificationStats(userId: 'u6', userName: 'Kareem N.', totalPoints: 750, level: 'Wanderer'),
    GamificationStats(userId: 'u7', userName: 'Mostafa K.', totalPoints: 530, level: 'Wanderer'),
    GamificationStats(userId: 'u8', userName: 'Ziad W.', totalPoints: 410, level: 'Explorer'),
    GamificationStats(userId: 'u9', userName: 'Hassan R.', totalPoints: 220, level: 'Explorer'),
    GamificationStats(userId: 'u10', userName: 'Amr E.', totalPoints: 95, level: 'Explorer'),
  ];
}
