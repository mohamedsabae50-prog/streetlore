import 'package:flutter/material.dart';
import '../../data/models/place_model.dart';

class BestTimeRecommendation {
  final int score;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  const BestTimeRecommendation({
    required this.score,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  bool get isGoodNow => score >= 70;
  bool get isOkayNow => score >= 40 && score < 70;
  bool get isBadNow => score < 40;
}

class BestTimeService {
  BestTimeService._();
  static final BestTimeService instance = BestTimeService._();

  BestTimeRecommendation recommend(PlaceModel place, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final hour = t.hour;
    final minute = t.minute;
    final weekday = t.weekday;
    final isWeekend = weekday == DateTime.friday || weekday == DateTime.saturday;
    final category = place.category.toLowerCase();

    final slot = _slotFor(hour);
    final windows = _windowsFor(category);

    int bestScore = 0;
    _Window best = windows.first;
    for (final w in windows) {
      final s = _scoreForSlot(slot, w, isWeekend: isWeekend, hour: hour, minute: minute);
      if (s > bestScore) {
        bestScore = s;
        best = w;
      }
    }

    final nextWindow = _nextWindowText(windows, t, category);

    if (bestScore >= 75) {
      return BestTimeRecommendation(
        score: bestScore,
        label: 'Go now',
        hint: best.reason,
        icon: best.icon,
        color: const Color(0xFF10B981),
      );
    } else if (bestScore >= 50) {
      return BestTimeRecommendation(
        score: bestScore,
        label: 'Decent now',
        hint: best.reason,
        icon: best.icon,
        color: const Color(0xFFF59E0B),
      );
    } else {
      return BestTimeRecommendation(
        score: bestScore,
        label: nextWindow.title,
        hint: nextWindow.body,
        icon: best.icon,
        color: const Color(0xFFEF4444),
      );
    }
  }

  String _slotFor(int hour) {
    if (hour < 6) return 'late_night';
    if (hour < 9) return 'early_morning';
    if (hour < 12) return 'morning';
    if (hour < 15) return 'midday';
    if (hour < 18) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  List<_Window> _windowsFor(String category) {
    if (category.contains('nature') || category.contains('beach')) {
      return const [
        _Window('early_morning', 95, 'Quietest, best light', Icons.wb_twilight_rounded),
        _Window('morning', 80, 'Cool, photogenic', Icons.wb_sunny_rounded),
        _Window('midday', 30, 'Hot & crowded', Icons.wb_sunny_outlined),
        _Window('afternoon', 55, 'Warm but ok', Icons.wb_cloudy_rounded),
        _Window('evening', 90, 'Golden hour magic', Icons.wb_twilight_rounded),
        _Window('night', 20, 'Closed, unsafe', Icons.nightlight_round),
      ];
    }
    if (category.contains('historical')) {
      return const [
        _Window('early_morning', 90, 'Cool & empty', Icons.wb_twilight_rounded),
        _Window('morning', 88, 'Best for photos', Icons.wb_sunny_rounded),
        _Window('midday', 55, 'Hot but shaded', Icons.wb_sunny_outlined),
        _Window('afternoon', 70, 'Soft light', Icons.wb_cloudy_rounded),
        _Window('evening', 60, 'Often closing', Icons.wb_twilight_rounded),
        _Window('night', 5, 'Closed', Icons.nightlight_round),
      ];
    }
    if (category.contains('culture') || category.contains('museum')) {
      return const [
        _Window('early_morning', 65, 'Quiet if open', Icons.wb_twilight_rounded),
        _Window('morning', 92, 'Cool indoor, low crowd', Icons.wb_sunny_rounded),
        _Window('midday', 70, 'Indoor climate ok', Icons.wb_sunny_outlined),
        _Window('afternoon', 80, 'Easy to walk in', Icons.wb_cloudy_rounded),
        _Window('evening', 88, 'Cooler & atmospheric', Icons.nightlight_round),
        _Window('night', 10, 'Closed', Icons.nightlight_round),
      ];
    }
    if (category.contains('food')) {
      return const [
        _Window('early_morning', 30, 'Too early', Icons.wb_twilight_rounded),
        _Window('morning', 60, 'Breakfast spots', Icons.wb_sunny_rounded),
        _Window('midday', 90, 'Lunch prime time', Icons.restaurant_rounded),
        _Window('afternoon', 50, 'Off hours', Icons.coffee_rounded),
        _Window('evening', 95, 'Dinner magic', Icons.local_dining_rounded),
        _Window('night', 70, 'Still open', Icons.nightlight_round),
      ];
    }
    return const [
      _Window('early_morning', 75, 'Quiet & cool', Icons.wb_twilight_rounded),
      _Window('morning', 85, 'Best for photos', Icons.wb_sunny_rounded),
      _Window('midday', 55, 'Hot & bright', Icons.wb_sunny_outlined),
      _Window('afternoon', 65, 'Warm but ok', Icons.wb_cloudy_rounded),
      _Window('evening', 80, 'Soft light', Icons.wb_twilight_rounded),
      _Window('night', 25, 'Mostly closed', Icons.nightlight_round),
    ];
  }

  int _scoreForSlot(
    String slot,
    _Window w, {
    required bool isWeekend,
    required int hour,
    required int minute,
  }) {
    var base = switch (slot) {
      'early_morning' => _match(w.slot, 'early_morning'),
      'morning' => _match(w.slot, 'morning'),
      'midday' => _match(w.slot, 'midday'),
      'afternoon' => _match(w.slot, 'afternoon'),
      'evening' => _match(w.slot, 'evening'),
      'night' => _match(w.slot, 'night'),
      'late_night' => 0,
      _ => 50,
    };
    if (base <= 0) return base;
    if (isWeekend && (slot == 'morning' || slot == 'afternoon')) {
      base = (base * 0.85).round();
    }
    if (!isWeekend && slot == 'morning') {
      base = (base * 1.05).round().clamp(0, 100);
    }
    return base;
  }

  int _match(String a, String b) {
    if (a == b) return 95;
    final hour = const {
      'early_morning': 0,
      'morning': 1,
      'midday': 2,
      'afternoon': 3,
      'evening': 4,
      'night': 5,
    };
    final da = (hour[a]! - hour[b]!).abs();
    if (da == 0) return 95;
    if (da == 1) return 70;
    if (da == 2) return 45;
    if (da == 3) return 25;
    return 10;
  }

  _NextWindow _nextWindowText(List<_Window> windows, DateTime now, String category) {
    final hour = now.hour;
    int? nextBestHour;
    int bestScore = 0;
    String label = 'Try later today';
    for (final w in windows) {
      final slotStart = _slotStart(w.slot);
      if (slotStart > hour) {
        final s = w.score;
        if (s > bestScore) {
          bestScore = s;
          nextBestHour = slotStart;
          label = w.reason;
        }
      }
    }
    if (nextBestHour == null) {
      final morningStart = 7;
      final bestMorning = windows
          .where((w) => w.slot == 'morning' || w.slot == 'early_morning')
          .fold<_Window>(windows.first, (a, b) => a.score >= b.score ? a : b);
      return _NextWindow(
        title: 'Come back tomorrow',
        body: 'Best at $morningStart-${morningStart + 2} AM — ${bestMorning.reason}',
      );
    }
    final end = nextBestHour + 1;
    return _NextWindow(
      title: 'Try $nextBestHour-${end > 12 ? end - 12 : end} ${end >= 12 ? 'PM' : 'AM'}',
      body: label,
    );
  }

  int _slotStart(String slot) {
    switch (slot) {
      case 'early_morning':
        return 6;
      case 'morning':
        return 9;
      case 'midday':
        return 12;
      case 'afternoon':
        return 15;
      case 'evening':
        return 18;
      case 'night':
        return 21;
      default:
        return 9;
    }
  }
}

class _Window {
  final String slot;
  final int score;
  final String reason;
  final IconData icon;
  const _Window(this.slot, this.score, this.reason, this.icon);
}

class _NextWindow {
  final String title;
  final String body;
  const _NextWindow({required this.title, required this.body});
}
