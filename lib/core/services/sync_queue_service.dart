import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_storage_service.dart';
import 'supabase_service.dart';

class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService instance = SyncQueueService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;
  bool _flushing = false;

  bool get isOnline => _isOnline;

  Future<void> init() async {
    if (_subscription != null) return;
    if (!Hive.isBoxOpen(OfflineStorageService.syncQueueBox)) {
      debugPrint(
        'SyncQueueService: Hive queue is unavailable; offline check-ins '
        'cannot be persisted.',
      );
    }

    try {
      final current = await _connectivity.checkConnectivity();
      _updateConnection(current);
    } catch (error) {
      debugPrint('SyncQueueService connectivity check failed: $error');
    }
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnection,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('SyncQueueService connectivity listener failed: $error');
      },
    );
    if (_isOnline) {
      unawaited(flush());
    }
  }

  Future<bool> enqueueCheckin({
    required String userId,
    required String placeId,
    required DateTime checkedInAt,
  }) async {
    if (!Hive.isBoxOpen(OfflineStorageService.syncQueueBox)) {
      debugPrint(
        'SyncQueueService cannot queue a check-in: Hive is not ready.',
      );
      return false;
    }
    try {
      final id = const Uuid().v4();
      await Hive.box(OfflineStorageService.syncQueueBox).put(
        id,
        jsonEncode({
          'type': 'checkin',
          'user_id': userId,
          'place_id': placeId,
          'checked_in_at': checkedInAt.toUtc().toIso8601String(),
        }),
      );
      return true;
    } catch (error) {
      debugPrint('SyncQueueService failed to persist a check-in: $error');
      return false;
    }
  }

  Future<void> flush() async {
    if (_flushing ||
        !_isOnline ||
        !Hive.isBoxOpen(OfflineStorageService.syncQueueBox)) {
      return;
    }
    final client = SupabaseService.instance.clientOrNull;
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null) return;

    _flushing = true;
    try {
      final box = Hive.box(OfflineStorageService.syncQueueBox);
      for (final key in box.keys.toList(growable: false)) {
        final encoded = box.get(key);
        if (encoded is! String) {
          debugPrint('SyncQueueService found an invalid queue item: $key');
          continue;
        }

        late final Map<String, dynamic> item;
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Queue item must be a JSON object.');
          }
          item = decoded;
        } on FormatException catch (error) {
          debugPrint('SyncQueueService found malformed item $key: $error');
          continue;
        }

        if (item['type'] != 'checkin' ||
            item['user_id'] is! String ||
            item['place_id'] is! String ||
            item['checked_in_at'] is! String) {
          debugPrint('SyncQueueService found an unsupported queue item: $key');
          continue;
        }
        if (item['user_id'] != currentUserId) continue;

        try {
          final existing = await client
              .from('place_checkins')
              .select('id')
              .eq('user_id', currentUserId)
              .eq('place_id', item['place_id'] as String)
              .eq('checked_in_at', item['checked_in_at'] as String)
              .maybeSingle();
          if (existing == null) {
            await client.from('place_checkins').insert({
              'user_id': currentUserId,
              'place_id': item['place_id'],
              'checked_in_at': item['checked_in_at'],
            });
          }
          await box.delete(key);
        } on PostgrestException catch (error) {
          debugPrint('SyncQueueService could not sync item $key: $error');
          break;
        } catch (error) {
          debugPrint('SyncQueueService could not sync item $key: $error');
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void _updateConnection(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    if (_isOnline && !wasOnline) {
      unawaited(flush());
    }
  }
}
