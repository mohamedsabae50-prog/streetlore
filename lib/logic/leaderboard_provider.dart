import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../data/models/gamification_stats.dart';

enum LeaderboardPeriod {
  week('week'),
  month('month'),
  allTime('all_time');

  const LeaderboardPeriod(this.rpcValue);

  final String rpcValue;
}

enum LeaderboardMetric {
  checkIns('check_ins'),
  longestStreak('longest_streak'),
  hiddenGems('hidden_gems');

  const LeaderboardMetric(this.rpcValue);

  final String rpcValue;
}

class CityLeaderboardEntry {
  const CityLeaderboardEntry({
    required this.stats,
    required this.score,
    required this.checkIns,
    required this.longestStreak,
    required this.hiddenGems,
  });

  final GamificationStats stats;
  final int score;
  final int checkIns;
  final int longestStreak;
  final int hiddenGems;

  factory CityLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CityLeaderboardEntry(
      stats: GamificationStats.fromJson(json),
      score: (json['score'] as num?)?.toInt() ?? 0,
      checkIns: (json['check_ins'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      hiddenGems: (json['hidden_gems'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardProvider extends ChangeNotifier {
  List<CityLeaderboardEntry> _entries = [];
  bool _loading = false;
  String? _error;
  LeaderboardPeriod _period = LeaderboardPeriod.week;
  LeaderboardMetric _metric = LeaderboardMetric.checkIns;
  int _requestGeneration = 0;

  List<CityLeaderboardEntry> get entries =>
      List<CityLeaderboardEntry>.unmodifiable(_entries);
  bool get isLoading => _loading;
  String? get error => _error;
  LeaderboardPeriod get period => _period;
  LeaderboardMetric get metric => _metric;

  Future<void> load({
    LeaderboardPeriod? period,
    LeaderboardMetric? metric,
    int limit = 50,
  }) async {
    _period = period ?? _period;
    _metric = metric ?? _metric;
    final generation = ++_requestGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await SupabaseService.instance.fetchCityLeaderboard(
        period: _period.rpcValue,
        metric: _metric.rpcValue,
        limit: limit,
      );
      if (generation != _requestGeneration) return;
      _entries = rows.map(CityLeaderboardEntry.fromJson).toList();
    } catch (error, stackTrace) {
      if (generation != _requestGeneration) return;
      _entries = [];
      _error = 'Could not load the city leaderboard: $error';
      debugPrint('LeaderboardProvider.load failed: $error\n$stackTrace');
    } finally {
      if (generation == _requestGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }
}
