import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
      _logError('fetchMessages', e);
      return const [];
    }
  }

  Future<void> postMessage(ChatMessage message) async {
    if (_client == null) return;
    try {
      await _client!.from('place_chat').insert(message.toJson()).select();
    } catch (e) {
      _logError('postMessage', e);
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
      _logError('streamMessages', e);
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
      _logError('fetchLeaderboard', e);
      return const [];
    }
  }

  Future<void> pushStats(GamificationStats stats) async {
    if (_client == null) return;
    try {
      await _client!.from('leaderboard').upsert(stats.toJson()).select();
    } catch (e) {
      _logError('pushStats', e);
    }
  }

  Future<GamificationStats?> pullStats(String userId) async {
    if (_client == null) return null;
    try {
      final res = await _client!
          .from('leaderboard')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (res == null) return null;
      return GamificationStats.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      _logError('pullStats($userId)', e);
      return null;
    }
  }

  Future<bool> pushSavedPlace(String userId, PlaceModel place) async {
    if (_client == null || userId.isEmpty) return false;
    try {
      await _client!.from('saved_places').upsert({
        'user_id': userId,
        'place_id': place.id,
        'place_data': jsonEncode(place.toJson()),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,place_id').select();
      return true;
    } catch (e) {
      _logError('pushSavedPlace($userId, ${place.id})', e);
      return false;
    }
  }

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
      _logError('deleteSavedPlace($userId, $placeId)', e);
      return false;
    }
  }

  Future<({bool ok, PostgrestException? error})> registerCheckin(
    String userId,
    String placeId,
  ) async {
    if (_client == null || userId.isEmpty) {
      return (ok: false, error: null);
    }
    try {
      await _client!.from('place_checkins').insert({
        'user_id': userId,
        'place_id': placeId,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
      }).select();
      return (ok: true, error: null);
    } on PostgrestException catch (e) {
      _logError('registerCheckin($userId, $placeId)', e);
      return (ok: false, error: e);
    } catch (e) {
      _logError('registerCheckin($userId, $placeId)', e);
      return (
        ok: false,
        error: PostgrestException(
          message: e.toString(),
          code: 'unknown',
          details: null,
          hint: null,
        ),
      );
    }
  }

  /// v1.0.63: drop a previously-registered check-in for the given
  /// (user, place) pair. Used by the "Un-visit" button on Place Details.
  /// Returns true if the row was deleted (or there was nothing to delete),
  /// false on hard DB error.
  Future<bool> deleteCheckin(String userId, String placeId) async {
    if (_client == null || userId.isEmpty || placeId.isEmpty) return true;
    try {
      await _client!
          .from('place_checkins')
          .delete()
          .eq('user_id', userId)
          .eq('place_id', placeId);
      return true;
    } on PostgrestException catch (e) {
      _logError('deleteCheckin($userId, $placeId)', e);
      return false;
    } catch (e) {
      _logError('deleteCheckin($userId, $placeId)', e);
      return false;
    }
  }

  Future<({int savedPlaces, int checkIns})> countUserRows(String userId) async {
    if (_client == null || userId.isEmpty) {
      return (savedPlaces: 0, checkIns: 0);
    }
    int saved = 0;
    int checkins = 0;
    try {
      final savedRes = await _client!
          .from('saved_places')
          .select('user_id')
          .eq('user_id', userId)
          .count();
      saved = (savedRes as dynamic).count as int? ?? 0;
    } catch (e) {
      _logError('countUserRows(saved_places)', e);
    }
    try {
      final checkRes = await _client!
          .from('place_checkins')
          .select('user_id')
          .eq('user_id', userId)
          .count();
      checkins = (checkRes as dynamic).count as int? ?? 0;
    } catch (e) {
      _logError('countUserRows(place_checkins)', e);
    }
    return (savedPlaces: saved, checkIns: checkins);
  }

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
                return PlaceModel.fromJson(Map<String, dynamic>.from(data));
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
      _logError('pullSavedPlaces', e);
      return const [];
    }
  }

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
      _logError('pullSavedTours', e);
      return const [];
    }
  }

  void _logError(String method, Object e) {
    if (e is PostgrestException) {
      debugPrint(
        'SupabaseService.$method: PostgrestException '
        '[code=${e.code}, details=${e.details}]: ${e.message}',
      );
    } else {
      debugPrint('SupabaseService.$method error: $e');
    }
  }

  // v1.0.73 — proxied AI + account-delete wrappers. Both functions
  // require the user to present their Supabase access token via the
  // `Authorization: Bearer …` header.

  /// Route an AI request through the secure `ai-proxy` Edge Function
  /// (PR #3). The real GEMINI_API_KEY lives only on the function and
  /// is never sent to the client.
  ///
  /// [body] is the raw Gemini REST request body (contents + optional
  /// generationConfig). The function picks the model from
  /// `body['model']` (default `gemini-2.5-flash`).
  Future<Map<String, dynamic>> aiProxyInvoke(
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final client = clientOrNull;
    if (client == null) {
      throw Exception('Supabase client not initialized');
    }
    final token = accessToken ?? client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty) {
      throw Exception('Not signed in');
    }
    final uri = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/ai-proxy');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 429) {
      throw Exception(
        'AI_QUOTA_EXCEEDED: you have used all your daily AI requests.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('ai-proxy HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// Request full account + data deletion per Apple App Store and
  /// Google Play Store account-deletion requirements (PR #6). Calls
  /// the `delete-account` Edge Function which uses the service_role key
  /// to drop every user-owned row, then the auth.users entry itself.
  Future<Map<String, dynamic>> deleteAccount({String? accessToken}) async {
    final client = clientOrNull;
    if (client == null) {
      throw Exception('Supabase client not initialized');
    }
    final token = accessToken ?? client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty) {
      throw Exception('Not signed in');
    }
    final uri = Uri.parse(
      '${AppConfig.supabaseUrl}/functions/v1/delete-account',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'delete-account HTTP ${response.statusCode}: ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
