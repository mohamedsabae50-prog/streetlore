import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakProvider extends ChangeNotifier {
  static const _kPrefix = 'streak_v2_';

  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastVisitDate;
  int _totalVisitDays = 0;
  String _userId = '';

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  DateTime? get lastVisitDate => _lastVisitDate;
  int get totalVisitDays => _totalVisitDays;

  bool get hasStreakToday => _isSameDay(_lastVisitDate, DateTime.now());

  StreakProvider() {
    _load();
  }

  Future<void> setUserId(String userId) async {
    if (userId.isEmpty || userId == _userId) return;
    await _save();
    _userId = userId;
    _currentStreak = 0;
    _longestStreak = 0;
    _totalVisitDays = 0;
    _lastVisitDate = null;
    await _load();
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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
  }

  Future<void> _save() async {
    if (_userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
        'totalVisitDays': _totalVisitDays,
        'lastVisitDate': _lastVisitDate?.toIso8601String(),
      }),
    );
  }

  Future<int> registerVisit({DateTime? when}) async {
    if (_userId.isEmpty) return 0;
    final t = when ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);

    if (!_isSameDay(_lastVisitDate, t)) {
      _totalVisitDays += 1;
    }
    _lastVisitDate = today;
    _currentStreak += 1;

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

  String get _key => '$_kPrefix$_userId';
}
