import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gamification_stats.dart';

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
          'SupabaseService: disabled in config - using local mocks for social features.');
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      debugPrint('SupabaseService: initialised.');
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
          .map((rows) => rows
              .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
              .toList());
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
}
