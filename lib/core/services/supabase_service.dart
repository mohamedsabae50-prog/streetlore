import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gamification_stats.dart';
import '../../data/models/place_model.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient? _client;
  bool _initialised = false;

  SupabaseClient? get clientOrNull => _client;
  bool get isLive => _client != null;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    if (!AppConfig.supabaseEnabled) {
      debugPrint(
        'SupabaseService: disabled in config - using local mocks for social features.',
      );
      return;
    }
    try {
      _client = Supabase.instance.client;
    } catch (e) {
      debugPrint('SupabaseService: init failed: $e');
      _client = null;
    }
  }

  Future<List<ChatMessage>> fetchMessages(String placeId) async {
    if (_client == null) return const [];
    try {
      final res = await _client!
          .from('place_chat')
          .select()
          .eq('place_id', placeId)
          .order('sent_at', ascending: true)
          .limit(100);
      return (res as List)
          .map((j) => ChatMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase.fetchMessages error: $e');
      return const [];
    }
  }

  Future<void> postMessage(ChatMessage message) async {
    if (_client == null) return;
    try {
      await _client!.from('place_chat').insert(message.toJson());
    } catch (e) {
      debugPrint('Supabase.postMessage error: $e');
    }
  }

  Stream<List<ChatMessage>>? streamMessages(String placeId) {
    if (_client == null) return null;
    try {
      return _client!
          .from('place_chat')
          .stream(primaryKey: ['id'])
          .eq('place_id', placeId)
          .order('sent_at')
          .map(
            (rows) => rows
                .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
                .toList(),
          );
    } catch (e) {
      debugPrint('Supabase.streamMessages error: $e');
      return null;
    }
  }

  Future<List<GamificationStats>> fetchLeaderboard({int limit = 50}) async {
    if (_client == null) return const [];
    try {
      final res = await _client!
          .from('leaderboard')
          .select()
          .order('total_points', ascending: false)
          .limit(limit);
      return (res as List)
          .map((j) => GamificationStats.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase.fetchLeaderboard error: $e');
      return const [];
    }
  }

  Future<void> pushStats(GamificationStats stats) async {
    if (_client == null) return;
    try {
      await _client!.from('leaderboard').upsert(stats.toJson());
    } catch (e) {
      debugPrint('Supabase.pushStats error: $e');
    }
  }

  /// Pull the stats row for [userId] from the leaderboard table. Returns
  /// `null` when the user has no row yet or when Supabase is unavailable
  /// (the caller decides whether to fall back to local cached stats).
  Future<GamificationStats?> pullStats(String userId) async {
    if (_client == null) return null;
    try {
      final res = await _client!
          .from('leaderboard')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (res == null) return null;
      return GamificationStats.fromJson(
        Map<String, dynamic>.from(res as Map),
      );
    } catch (e) {
      debugPrint('Supabase.pullStats error: $e');
      return null;
    }
  }

  /// Push (upsert) a single saved place for [userId] to the `saved_places`
  /// table. The whole `PlaceModel` is JSON-encoded into the `place_data`
  /// JSONB column alongside `user_id` and `saved_at`. This is what makes
  /// the user's saved list survive a logout / app reinstall / device
  /// switch — SharedPreferences alone is not enough.
  Future<bool> pushSavedPlace(String userId, PlaceModel place) async {
    if (_client == null || userId.isEmpty) return false;
    try {
      await _client!.from('saved_places').upsert({
        'user_id': userId,
        'place_id': place.id,
        'place_data': jsonEncode(place.toJson()),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,place_id');
      return true;
    } catch (e) {
      debugPrint('Supabase.pushSavedPlace($userId, ${place.id}) error: $e');
      return false;
    }
  }

  /// Delete a saved place for [userId].
  Future<bool> deleteSavedPlace(String userId, String placeId) async {
    if (_client == null || userId.isEmpty) return false;
    try {
      await _client!
          .from('saved_places')
          .delete()
          .eq('user_id', userId)
          .eq('place_id', placeId);
      return true;
    } catch (e) {
      debugPrint('Supabase.deleteSavedPlace($userId, $placeId) error: $e');
      return false;
    }
  }

  /// Record a check-in event for [userId] at [placeId]. Also increments
  /// `places_visited` on the user row so the counter is always live.
  Future<bool> registerCheckin(String userId, String placeId) async {
    if (_client == null || userId.isEmpty) return false;
    try {
      await _client!.from('place_checkins').insert({
        'user_id': userId,
        'place_id': placeId,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint(
        'Supabase.registerCheckin($userId, $placeId) error: $e',
      );
      return false;
    }
  }

  /// Pull every saved place belonging to [userId] from the `saved_places`
  /// table. The shape mirrors `PlaceModel.toJson` so we can rebuild the
  /// `PlaceModel` straight from the response.
  Future<List<PlaceModel>> pullSavedPlaces(String userId) async {
    if (_client == null) return const [];
    try {
      final res = await _client!
          .from('saved_places')
          .select('place_data')
          .eq('user_id', userId)
          .order('saved_at', ascending: false);
      final list = (res as List)
          .map((row) {
            try {
              final data = (row as Map<String, dynamic>)['place_data'];
              if (data is String) {
                return PlaceModel.fromJson(
                  Map<String, dynamic>.from(jsonDecode(data) as Map),
                );
              }
              if (data is Map) {
                return PlaceModel.fromJson(
                  Map<String, dynamic>.from(data),
                );
              }
              return null;
            } catch (_) {
              return null;
            }
          })
          .whereType<PlaceModel>()
          .toList();
      return list;
    } catch (e) {
      debugPrint('Supabase.pullSavedPlaces error: $e');
      return const [];
    }
  }

  /// Pull all tours the user saved under their account.
  Future<List<Map<String, dynamic>>> pullSavedTours(String userId) async {
    if (_client == null) return const [];
    try {
      final res = await _client!
          .from('saved_tours')
          .select('tour_data')
          .eq('user_id', userId);
      return (res as List)
          .map((row) {
            final data = (row as Map<String, dynamic>)['tour_data'];
            if (data is String) {
              try {
                return Map<String, dynamic>.from(jsonDecode(data) as Map);
              } catch (_) {
                return null;
              }
            }
            if (data is Map) {
              return Map<String, dynamic>.from(data);
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('Supabase.pullSavedTours error: $e');
      return const [];
    }
  }
}
