import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_storage_service.dart';

const String kGlobalProgressResetEpoch = 'reset_2026_11_16_v1';

class GlobalProgressResetService {
  GlobalProgressResetService._();

  static const _epochKey = 'global_progress_reset_epoch';
  static const _queueResetPendingKey = 'global_progress_reset_queue_pending';
  static const _progressKeyPrefixes = [
    'gamification_stats_v2_',
    'gamification_activity_',
    'gamification_post_reset_action_',
    'streak_v3_',
    'achievements_v2_',
    'visited_place_ids_',
  ];

  static Future<void>? _resetFuture;

  static Future<void> ensureReset() {
    final pending = _resetFuture;
    if (pending != null) return pending;

    final reset = _ensureReset();
    _resetFuture = reset;
    return reset.whenComplete(() {
      if (identical(_resetFuture, reset)) _resetFuture = null;
    });
  }

  static Future<void> clearPendingCheckinQueue() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_queueResetPendingKey) != true) return;
    if (!Hive.isBoxOpen(OfflineStorageService.syncQueueBox)) return;

    final box = Hive.box(OfflineStorageService.syncQueueBox);
    for (final key in box.keys.toList(growable: false)) {
      final encoded = box.get(key);
      if (encoded is! String) continue;

      dynamic decoded;
      try {
        decoded = jsonDecode(encoded);
      } on FormatException catch (error) {
        debugPrint(
          'GlobalProgressResetService: invalid queued item $key: $error',
        );
        continue;
      }
      if (decoded is Map && decoded['type'] == 'checkin') {
        await box.delete(key);
      }
    }

    await prefs.remove(_queueResetPendingKey);
  }

  static Future<void> _ensureReset() async {
    final prefs = await SharedPreferences.getInstance();
    final needsReset = prefs.getString(_epochKey) != kGlobalProgressResetEpoch;

    if (needsReset) {
      for (final key in prefs.getKeys()) {
        if (_progressKeyPrefixes.any((prefix) => key.startsWith(prefix)) ||
            key == 'automatically_visited_tour_ids') {
          await prefs.remove(key);
        }
      }
      await prefs.setBool(_queueResetPendingKey, true);
    }

    await clearPendingCheckinQueue();
    if (needsReset) {
      await prefs.setString(_epochKey, kGlobalProgressResetEpoch);
    }
  }
}
