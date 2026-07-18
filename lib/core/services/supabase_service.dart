import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gamification_stats.dart';
import '../../data/models/user_route.dart';

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
    if (_client == null) return _mockMessages(placeId);
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
      return _mockMessages(placeId);
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
    if (_client == null) return _mockLeaderboard();
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
      return _mockLeaderboard();
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

  
  Future<List<UserRoute>> fetchRoutes({int limit = 50}) async {
    if (_client == null) return _mockRoutes();
    try {
      final res = await _client!
          .from('user_routes')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List)
          .map((j) => UserRoute.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase.fetchRoutes error: $e');
      return _mockRoutes();
    }
  }

  Future<void> postRoute(UserRoute route) async {
    if (_client == null) return;
    try {
      await _client!.from('user_routes').insert(route.toJson());
    } catch (e) {
      debugPrint('Supabase.postRoute error: $e');
    }
  }

  Future<void> likeRoute(String routeId) async {
    if (_client == null) return;
    try {
      await _client!.rpc('increment_route_likes', params: {'route_id': routeId});
    } catch (e) {
      debugPrint('Supabase.likeRoute error: $e');
    }
  }

  
  List<ChatMessage> _mockMessages(String placeId) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'm1_$placeId',
        placeId: placeId,
        userId: 'u_1',
        userName: 'Layla N.',
        text: 'Just arrived - the sunset here is unreal ',
        sentAt: now.subtract(const Duration(minutes: 6)),
        userAvatarColor: '0xFF7C3AED',
      ),
      ChatMessage(
        id: 'm2_$placeId',
        placeId: placeId,
        userId: 'u_2',
        userName: 'Marco R.',
        text: 'Anyone recommend a coffee nearby?',
        sentAt: now.subtract(const Duration(minutes: 3)),
        userAvatarColor: '0xFFE11D48',
      ),
      ChatMessage(
        id: 'm3_$placeId',
        placeId: placeId,
        userId: 'u_3',
        userName: 'Yara H.',
        text: 'Trianon for the granita, you\'ll thank me later.',
        sentAt: now.subtract(const Duration(minutes: 1)),
        userAvatarColor: '0xFF10B981',
      ),
    ];
  }

  List<GamificationStats> _mockLeaderboard() {
    return [
      GamificationStats(
        userId: 'u_a',
        userName: 'Sara the Cartographer',
        avatarColorHex: '0xFFE11D48',
        totalPoints: 4280,
        placesVisited: 22,
        routesCreated: 3,
        reviewsPosted: 14,
        level: 'Cartographer',
        badges: const [
          Badge(
            id: 'b1',
            name: 'First Steps',
            description: 'Visited your first place',
            iconName: 'explore',
            tier: 'bronze',
            earnedAt: null,
          ),
        ],
      ),
      GamificationStats(
        userId: 'u_b',
        userName: 'Omar the Wanderer',
        avatarColorHex: '0xFF0F172A',
        totalPoints: 3120,
        placesVisited: 17,
        reviewsPosted: 9,
        level: 'Cartographer',
      ),
      GamificationStats(
        userId: 'u_c',
        userName: 'Layla N.',
        avatarColorHex: '0xFF7C3AED',
        totalPoints: 1840,
        placesVisited: 11,
        reviewsPosted: 6,
        level: 'Wanderer',
      ),
      GamificationStats(
        userId: 'u_d',
        userName: 'Marco Rossi',
        avatarColorHex: '0xFFF59E0B',
        totalPoints: 920,
        placesVisited: 6,
        reviewsPosted: 3,
        level: 'Wanderer',
      ),
      GamificationStats(
        userId: 'u_e',
        userName: 'You',
        avatarColorHex: '0xFF3B82F6',
        totalPoints: 70,
        placesVisited: 1,
        reviewsPosted: 0,
        level: 'Explorer',
      ),
    ];
  }

  List<UserRoute> _mockRoutes() {
    final now = DateTime.now();
    return [
      UserRoute(
        id: 'r1',
        title: 'Sunset at Qaitbay Citadel',
        description:
            'A 90-minute walking loop that hits the citadel at golden hour, with a seafood stop at Kadoura on the way back.',
        authorId: 'u_1',
        authorName: 'Layla N.',
        placeIds: const ['1', '22'],
        likes: 124,
        saves: 38,
        createdAt: now.subtract(const Duration(days: 2)),
        tags: const ['sunset', 'photography', 'food'],
      ),
      UserRoute(
        id: 'r2',
        title: 'Café Trail for the Slow Traveler',
        description:
            'Three of the oldest cafés in Alexandria, all within walking distance. Don\'t skip the granita.',
        authorId: 'u_2',
        authorName: 'Marco R.',
        placeIds: const ['19', '20', '30'],
        likes: 76,
        saves: 22,
        createdAt: now.subtract(const Duration(days: 5)),
        tags: const ['café', 'slow', 'history'],
      ),
      UserRoute(
        id: 'r3',
        title: 'Library -> Catacombs in One Morning',
        description:
            'Dense history route: Bibliotheca Alexandrina, then Pompey\'s Pillar, ending at the Kom el Shoqafa catacombs.',
        authorId: 'u_3',
        authorName: 'Yara H.',
        placeIds: const ['2', '7', '4'],
        likes: 211,
        saves: 64,
        createdAt: now.subtract(const Duration(days: 9)),
        tags: const ['history', 'morning', 'walking'],
      ),
    ];
  }
}
