import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/supabase_service.dart';

/// StreakProvider tracks the user's DAILY activity, not the total
/// number of visits.
///
/// Correct v1.0.56 semantics:
///   - `_currentStreak` counts CONSECUTIVE calendar days with at
///     least one check-in. Visiting twice on the same day is a
///     no-op.
///   - `_totalVisitDays` counts the number of UNIQUE calendar days
///     on which the user checked in at least once.
///   - `_longestStreak` is the longest consecutive-day run ever
///     achieved.
///   - `_visitedDates` is the set of unique calendar dates (yyyy-mm-dd)
///     the user has ever checked in.
class StreakProvider extends ChangeNotifier {
  static const _kPrefix = 'streak_v3_';

  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastVisitDate;
  int _totalVisitDays = 0;
  Set<String> _visitedDates = <String>{};
  String _userId = '';

  int get currentStreak {
    final lastVisit = _lastVisitDate;
    if (lastVisit == null ||
        _calendarDayDifference(DateTime.now(), lastVisit) > 1) {
      return 0;
    }
    return _currentStreak;
  }

  int get longestStreak => _longestStreak;
  DateTime? get lastVisitDate => _lastVisitDate;
  int get totalVisitDays => _totalVisitDays;
  Set<String> get visitedDates => Set<String>.unmodifiable(_visitedDates);

  bool get hasStreakToday {
    if (_lastVisitDate == null) return false;
    final today = _dateOnly(DateTime.now());
    return _dateOnly(_lastVisitDate!) == today;
  }

  Future<void> setUserId(String userId) async {
    if (userId == _userId) return;
    await _save();
    _userId = userId;
    _currentStreak = 0;
    _longestStreak = 0;
    _totalVisitDays = 0;
    _visitedDates = <String>{};
    _lastVisitDate = null;
    if (userId.isNotEmpty) await _load(userId);
    notifyListeners();
  }

  Future<void> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId != userId) return;
    final raw = prefs.getString('$_kPrefix$userId');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _currentStreak = (map['currentStreak'] as int?) ?? 0;
      _longestStreak = (map['longestStreak'] as int?) ?? 0;
      _totalVisitDays = (map['totalVisitDays'] as int?) ?? 0;
      final last = map['lastVisitDate'] as String?;
      _lastVisitDate = last == null ? null : DateTime.parse(last);
      final visitedRaw = map['visitedDates'];
      if (visitedRaw is List) {
        _visitedDates = visitedRaw
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet();
        if (_totalVisitDays == 0 && _visitedDates.isNotEmpty) {
          _totalVisitDays = _visitedDates.length;
        }
      }
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
        'visitedDates': _visitedDates.toList(),
      }),
    );
  }

  /// Records a visit at [when] (defaults to now).
  ///
  /// Rules (v1.0.56):
  ///   - Multiple check-ins on the SAME calendar day are a no-op
  ///     for both the streak and the total-days counter.
  ///   - The first check-in on a NEW calendar day:
  ///       * increments `_totalVisitDays` by 1;
  ///       * if the new day is exactly yesterday relative to
  ///         `_lastVisitDate`, increments `_currentStreak`;
  ///       * otherwise resets `_currentStreak` to 1.
  ///   - `_longestStreak` is updated only when current exceeds it.
  /// Returns the current streak after the call.
  Future<int> registerVisit({DateTime? when}) async {
    if (_userId.isEmpty) return _currentStreak;
    final day = _dateOnly(when ?? DateTime.now());
    if (!_visitedDates.add(_dateKey(day))) return currentStreak;
    _recomputeDerivedStats();
    await _save();
    notifyListeners();
    return currentStreak;
  }

  /// Reloads the authoritative check-in history for the current signed-in
  /// user. A null result means the server was unavailable; keep local state.
  Future<void> refreshFromRemote() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final timestamps = await SupabaseService.instance.pullCheckinTimestamps(
      userId,
    );
    if (timestamps == null || _userId != userId) return;
    await recomputeFromTimestamps(timestamps);
  }

  /// Recompute the streak and totalVisitDays from an arbitrary set
  /// of visit timestamps (used when the app knows about visits that
  /// happened while offline or via a different code path).
  Future<void> recomputeFromTimestamps(Iterable<DateTime> visits) async {
    if (_userId.isEmpty) return;
    final days = <String>{};
    for (final v in visits) {
      final localVisit = v.isUtc ? v.toLocal() : v;
      days.add(_dateKey(_dateOnly(localVisit)));
    }
    _visitedDates = days;
    _recomputeDerivedStats();
    await _save();
    notifyListeners();
  }

  void _recomputeDerivedStats() {
    _totalVisitDays = _visitedDates.length;
    final sortedDays = _visitedDates.toList()..sort();
    _lastVisitDate = sortedDays.isEmpty
        ? null
        : DateTime.parse(sortedDays.last);
    _currentStreak = _computeStreakFromDays(_visitedDates, _lastVisitDate);
    _longestStreak = _computeLongestStreak(sortedDays);
  }

  int _computeStreakFromDays(Set<String> days, DateTime? anchor) {
    if (days.isEmpty || anchor == null) return 0;
    if (_calendarDayDifference(DateTime.now(), anchor) > 1) return 0;
    var count = 0;
    var cursor = _dateOnly(anchor);
    while (days.contains(_dateKey(cursor))) {
      count += 1;
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  int _computeLongestStreak(List<String> sortedDays) {
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final key in sortedDays) {
      final day = DateTime.parse(key);
      if (previous == null || _calendarDayDifference(day, previous) != 1) {
        current = 1;
      } else {
        current += 1;
      }
      if (current > longest) longest = current;
      previous = day;
    }
    return longest;
  }

  void reset() {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalVisitDays = 0;
    _lastVisitDate = null;
    _visitedDates = <String>{};
    _save();
    notifyListeners();
  }

  int _calendarDayDifference(DateTime later, DateTime earlier) {
    final laterDay = DateTime.utc(later.year, later.month, later.day);
    final earlierDay = DateTime.utc(earlier.year, earlier.month, earlier.day);
    return laterDay.difference(earlierDay).inDays;
  }

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _key => '$_kPrefix$_userId';
}
