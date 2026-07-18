import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakProvider extends ChangeNotifier {
  static const _kKey = 'streak_v1';

  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastVisitDate;
  int _totalVisitDays = 0;

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  DateTime? get lastVisitDate => _lastVisitDate;
  int get totalVisitDays => _totalVisitDays;

  bool get hasStreakToday => _isSameDay(_lastVisitDate, DateTime.now());

  StreakProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _currentStreak = (map['currentStreak'] as int?) ?? 0;
      _longestStreak = (map['longestStreak'] as int?) ?? 0;
      _totalVisitDays = (map['totalVisitDays'] as int?) ?? 0;
      final last = map['lastVisitDate'] as String?;
      _lastVisitDate = last == null ? null : DateTime.parse(last);
    } catch (e) {
      debugPrint('StreakProvider load error: $e');
    }
    _refreshFromElapsed();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode({
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
        'totalVisitDays': _totalVisitDays,
        'lastVisitDate': _lastVisitDate?.toIso8601String(),
      }),
    );
  }

  void _refreshFromElapsed() {
    if (_lastVisitDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      _lastVisitDate!.year,
      _lastVisitDate!.month,
      _lastVisitDate!.day,
    );
    final diff = today.difference(last).inDays;
    if (diff > 1) {
      _currentStreak = 0;
    }
  }

  Future<int> registerVisit({DateTime? when}) async {
    final t = when ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);

    if (_lastVisitDate == null) {
      _currentStreak = 1;
      _totalVisitDays = 1;
      _lastVisitDate = today;
    } else {
      final last = DateTime(
        _lastVisitDate!.year,
        _lastVisitDate!.month,
        _lastVisitDate!.day,
      );
      final diff = today.difference(last).inDays;
      if (diff == 0) {
        // same day, no change
        notifyListeners();
        return 0;
      } else if (diff == 1) {
        _currentStreak += 1;
        _totalVisitDays += 1;
        _lastVisitDate = today;
      } else {
        _currentStreak = 1;
        _totalVisitDays += 1;
        _lastVisitDate = today;
      }
    }
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }
    await _save();
    notifyListeners();
    return _currentStreak;
  }

  void reset() {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalVisitDays = 0;
    _lastVisitDate = null;
    _save();
    notifyListeners();
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
