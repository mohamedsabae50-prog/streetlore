import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/gamification_stats.dart';
import '../../data/models/place_model.dart';
import '../../data/models/social_user.dart';
import 'sync_queue_service.dart';
import 'realtime_resilience.dart';
import 'activity_feed_filter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  SupabaseClient? _client;
  bool _initialised = false;

  SupabaseClient? get clientOrNull => _client;
  bool get isLive => _client != null;

  String? resolveUuidUserId(String? userId) {
    final candidate = userId?.trim() ?? '';
    if (_uuidPattern.hasMatch(candidate)) return candidate;
    final authenticatedId = _client?.auth.currentUser?.id ?? '';
    return _uuidPattern.hasMatch(authenticatedId) ? authenticatedId : null;
  }

  static Map<String, dynamic> normalizeAiChatLogsResponse(Object? response) {
    final envelope = response is Map
        ? Map<String, dynamic>.fromEntries(
            response.entries
                .where((entry) => entry.key is String)
                .map((entry) => MapEntry(entry.key as String, entry.value)),
          )
        : <String, dynamic>{};
    final rawItems = response is List
        ? response
        : envelope['threads'] is List
        ? envelope['threads']
        : envelope['sessions'] is List
        ? envelope['sessions']
        : envelope['logs'] is List
        ? envelope['logs']
        : envelope['items'] is List
        ? envelope['items']
        : const <dynamic>[];

    final items = (rawItems as List)
        .whereType<Map>()
        .map((item) {
          return Map<String, dynamic>.fromEntries(
            item.entries
                .where((entry) => entry.key is String)
                .map((entry) => MapEntry(entry.key as String, entry.value)),
          );
        })
        .toList(growable: false);
    final containsThreads = items.any((item) => item['messages'] is List);
    final threads = <Map<String, dynamic>>[];
    if (containsThreads) {
      for (final item in items) {
        final rawMessages = item['messages'];
        if (rawMessages is! List) continue;
        final messages = rawMessages
            .whereType<Map>()
            .map(
              (message) => _normalizeAiChatLog(
                Map<String, dynamic>.fromEntries(
                  message.entries
                      .where((entry) => entry.key is String)
                      .map(
                        (entry) => MapEntry(entry.key as String, entry.value),
                      ),
                ),
              ),
            )
            .toList(growable: false);
        if (messages.isEmpty) continue;
        threads.add({
          ...item,
          'user_id': item['user_id']?.toString() ?? '',
          'created_at':
              _normalizeIsoDate(item['created_at']) ??
              messages.first['created_at'],
          'messages': messages,
        });
      }
    } else {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var index = 0; index < items.length; index++) {
        final log = _normalizeAiChatLog(items[index], index: index);
        final sessionId = log['session_id'] as String?;
        final key = sessionId == null || sessionId.isEmpty
            ? 'legacy:${log['id']}'
            : '${log['user_id']}:$sessionId';
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(log);
      }
      for (final entry in grouped.entries) {
        final messages = entry.value;
        threads.add({
          'id': entry.key,
          'user_id': messages.first['user_id'],
          'session_id': messages.first['session_id'],
          'created_at': messages.first['created_at'],
          'last_message_at': messages.last['created_at'],
          'messages': messages,
        });
      }
      threads.sort(
        (left, right) => (right['last_message_at'] as String).compareTo(
          left['last_message_at'] as String,
        ),
      );
    }

    return {'threads': threads, 'has_more': envelope['has_more'] == true};
  }

  static Map<String, dynamic> _normalizeAiChatLog(
    Map<String, dynamic> log, {
    int index = 0,
  }) {
    final rawId = log['id'] ?? log['log_id'] ?? index;
    final rawSessionId = log['session_id'] ?? log['sessionId'];
    return {
      ...log,
      'id': rawId.toString(),
      'user_id': (log['user_id'] ?? log['userId'] ?? '').toString(),
      'session_id': rawSessionId?.toString(),
      'user_prompt':
          (log['user_prompt'] ?? log['prompt'] ?? log['user_message'] ?? '')
              .toString(),
      'ai_response':
          (log['ai_response'] ??
                  log['response'] ??
                  log['assistant_message'] ??
                  '')
              .toString(),
      'created_at':
          _normalizeIsoDate(log['created_at'] ?? log['timestamp']) ?? '',
    };
  }

  static String? _normalizeIsoDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toUtc().toIso8601String();
  }

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

  /// Inserts [message] into `place_chat`. Throws if the send fails (not signed
  /// in, RLS rejection, network) so the caller can tell the user — a failed
  /// send must never look like a delivered one.
  Future<void> postMessage(ChatMessage message) async {
    if (_client == null) return;
    try {
      // The insert policy requires user_id = auth.uid(), so take the id from
      // the live session rather than trusting the model's copy.
      final uid = _client!.auth.currentUser?.id;
      if (uid == null) {
        throw StateError('postMessage: no authenticated user');
      }
      await _client!.from('place_chat').insert({
        ...message.toJson(),
        'user_id': uid,
      });
    } catch (e) {
      _logError('postMessage', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchAiQuotaStatus() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final result = await client.rpc('get_my_ai_quota_status');
    if (result is! Map) {
      throw const FormatException('AI quota response was not an object.');
    }
    final status = Map<String, dynamic>.from(result);
    if (status['daily_limit'] is! num ||
        status['remaining'] is! num ||
        status['next_reset_at'] is! String) {
      throw const FormatException(
        'AI quota response is missing required fields.',
      );
    }
    return status;
  }

  Stream<List<ChatMessage>>? streamMessages(String placeId) {
    if (_client == null) return null;
    try {
      return swallowTransientRealtimeErrors(
        _client!
            .from('place_chat')
            .stream(primaryKey: ['id'])
            .eq('place_id', placeId)
            .order('sent_at')
            .map(
              (rows) => rows
                  .map(
                    (j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)),
                  )
                  .toList(),
            ),
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
          .select(
            'user_id,user_name,avatar_color_hex,total_points,places_visited,'
            'reviews_posted,photos_uploaded,level,badges,current_streak,'
            'longest_streak,total_visit_days',
          )
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

  Future<List<Map<String, dynamic>>> fetchCityLeaderboard({
    required String period,
    required String metric,
    int limit = 50,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    try {
      final result = await client.rpc(
        'get_city_leaderboard',
        params: {'p_period': period, 'p_metric': metric, 'p_limit': limit},
      );
      if (result is! List) {
        throw const FormatException('Leaderboard response was not a list.');
      }
      return result
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where(
            (row) => _uuidPattern.hasMatch(row['user_id']?.toString() ?? ''),
          )
          .toList(growable: false);
    } catch (e) {
      _logError('fetchCityLeaderboard($period, $metric)', e);
      rethrow;
    }
  }

  Future<List<SocialUser>> searchUsers(String query) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final result = await client.rpc(
      'search_users',
      params: {'p_query': query.trim(), 'p_limit': 30},
    );
    if (result is! List) {
      throw const FormatException('User search response was not a list.');
    }
    return result
        .map(
          (row) => SocialUser.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<SocialUser?> getSocialUser(String userId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final targetUserId = resolveUuidUserId(userId);
    if (targetUserId == null) return null;
    final result = await client.rpc(
      'get_public_profile',
      params: {'target_user_id': targetUserId},
    );
    if (result is! Map) {
      throw const FormatException('Public profile response was not an object.');
    }
    final user = SocialUser.fromJson(Map<String, dynamic>.from(result));
    if (user.userId.isEmpty) {
      return null;
    }
    return user;
  }

  Future<List<SocialUser>> getSocialUsers(List<String> userIds) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final resolvedUserIds = userIds
        .map(resolveUuidUserId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (resolvedUserIds.isEmpty) return const [];
    final result = await client.rpc(
      'get_public_profiles',
      params: {'p_user_ids': resolvedUserIds},
    );
    if (result is! List) {
      throw const FormatException('Public profiles response was not a list.');
    }
    return result
        .map(
          (row) => SocialUser.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFriendships() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to load friends.');
    }
    final rows = await client
        .from('friendships')
        .select('id, requester_id, recipient_id, status')
        .or('requester_id.eq.$userId,recipient_id.eq.$userId')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<String> getFriendshipState(String otherUserId) async {
    final userId = _client?.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to load friendship status.');
    final rows = await fetchFriendships();
    for (final row in rows) {
      final requesterId = row['requester_id']?.toString();
      final recipientId = row['recipient_id']?.toString();
      final status = row['status']?.toString();
      if (requesterId != otherUserId && recipientId != otherUserId) continue;
      if (status == 'accepted') return 'accepted';
      if (status == 'pending') {
        return requesterId == userId ? 'outgoing' : 'incoming';
      }
    }
    return 'none';
  }

  Future<String> sendFriendRequest(String targetUserId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is unavailable.');
    final resolvedTargetId = resolveUuidUserId(targetUserId);
    if (resolvedTargetId == null) {
      throw StateError('Sign in to send friend requests.');
    }
    final result = await client.rpc(
      'send_friend_request',
      params: {'target_user_id': resolvedTargetId},
    );
    if (result is! String) {
      throw const FormatException('Friend request response was invalid.');
    }
    return result;
  }

  Future<void> respondToFriendRequest(
    String requesterId, {
    required bool accept,
  }) async {
    final client = _client;
    final userId = resolveUuidUserId(client?.auth.currentUser?.id);
    if (client == null || userId == null) {
      throw StateError('Sign in to respond to friend requests.');
    }
    final resolvedRequesterId = resolveUuidUserId(requesterId);
    if (resolvedRequesterId == null) {
      throw StateError('Sign in to respond to friend requests.');
    }
    final request = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', resolvedRequesterId)
        .eq('recipient_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (request == null) {
      throw StateError('Friend request is no longer pending.');
    }
    await client.rpc(
      'respond_to_friend_request',
      params: {'request_id': request['id'], 'accept_request': accept},
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({
    int limit = 100,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to load notifications.');
    }
    try {
      final result = await client
          .from('notifications')
          .select(
            'id,recipient_id,actor_id,type,friendship_id,title,body,metadata,'
            'created_at,read_at',
          )
          .eq('recipient_id', userId)
          .neq('actor_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (error, stackTrace) {
      if (!isTransientSupabaseError(error)) rethrow;
      debugPrint(
        'SupabaseService.fetchNotifications transient network failure: '
        '$error\n$stackTrace',
      );
      return const [];
    }
  }

  Stream<List<Map<String, dynamic>>>? watchNotifications(String userId) {
    final client = _client;
    final recipientId = resolveUuidUserId(userId);
    if (client == null || recipientId == null) return null;
    return Stream.multi((controller) {
      var pollInFlight = false;
      Timer? pollTimer;
      StreamSubscription<List<Map<String, dynamic>>>? realtimeSubscription;

      Future<void> poll() async {
        if (pollInFlight) return;
        pollInFlight = true;
        try {
          controller.add(await fetchNotifications());
        } catch (error, stackTrace) {
          if (!isTransientNetworkError(error)) {
            controller.addError(error, stackTrace);
          }
        } finally {
          pollInFlight = false;
        }
      }

      final realtime = client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('recipient_id', recipientId)
          .neq('actor_id', recipientId)
          .order('created_at', ascending: false)
          .map(
            (rows) => rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false),
          );
      realtimeSubscription = swallowTransientRealtimeErrors(
        realtime,
        onTransientError: (error, stackTrace) {
          debugPrint('Notification realtime unavailable; polling: $error');
          unawaited(poll());
        },
      ).listen(controller.add, onError: controller.addError);
      pollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(poll()),
      );
      controller.onCancel = () async {
        pollTimer?.cancel();
        await realtimeSubscription?.cancel();
      };
    });
  }

  Future<void> markNotificationRead(String notificationId) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to update notifications.');
    }
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }

  Future<void> cancelFriendRequest(String targetUserId) async {
    final client = _client;
    final userId = resolveUuidUserId(client?.auth.currentUser?.id);
    if (client == null || userId == null) {
      throw StateError('Sign in to cancel friend requests.');
    }
    final resolvedTargetId = resolveUuidUserId(targetUserId);
    if (resolvedTargetId == null) {
      throw StateError('Sign in to cancel friend requests.');
    }
    final request = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('recipient_id', resolvedTargetId)
        .eq('status', 'pending')
        .maybeSingle();
    if (request == null) {
      throw StateError('Friend request is no longer pending.');
    }
    await client.rpc(
      'cancel_friend_request',
      params: {'request_id': request['id']},
    );
  }

  Future<void> removeFriend(String targetUserId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is unavailable.');
    final resolvedTargetId = resolveUuidUserId(targetUserId);
    if (resolvedTargetId == null) {
      throw StateError('Sign in to remove friends.');
    }
    await client.rpc(
      'remove_friend',
      params: {'target_user_id': resolvedTargetId},
    );
  }

  Future<Map<String, bool>> fetchFriendPrivacySettings() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to load friend privacy settings.');
    }
    final rows = await client
        .from('friend_privacy_settings')
        .select('friend_id, share_location_activity')
        .eq('user_id', userId);
    return {
      for (final row in rows as List)
        (row as Map)['friend_id'].toString():
            (row['share_location_activity'] as bool?) ?? true,
    };
  }

  Future<void> setFriendLocationActivitySharing(
    String friendId,
    bool enabled,
  ) async {
    final client = _client;
    final userId = resolveUuidUserId(client?.auth.currentUser?.id);
    if (client == null || userId == null) {
      throw StateError('Sign in to update friend privacy settings.');
    }
    final resolvedFriendId = resolveUuidUserId(friendId);
    if (resolvedFriendId == null) {
      throw StateError('Sign in to update friend privacy settings.');
    }
    await client.from('friend_privacy_settings').upsert({
      'user_id': userId,
      'friend_id': resolvedFriendId,
      'share_location_activity': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,friend_id');
  }

  Future<bool> fetchLocationActivitySharing() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to load privacy settings.');
    }
    final response = await client.rpc('get_my_profile_private');
    if (response is! Map) {
      throw const FormatException('Profile privacy response was invalid.');
    }
    final row = Map<String, dynamic>.from(response);
    return row['share_location_activity'] as bool? ?? true;
  }

  Future<void> setLocationActivitySharing(bool enabled) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Sign in to update privacy settings.');
    }
    await client
        .from('profiles')
        .update({
          'share_location_activity': enabled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getUserVisitedPlaces(
    String targetUserId,
  ) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final resolvedTargetId = resolveUuidUserId(targetUserId);
    if (resolvedTargetId == null) return const [];
    final result = await client.rpc(
      'get_user_visited_places',
      params: {'target_user_id': resolvedTargetId},
    );
    if (result is! List) {
      throw const FormatException('Visited places response was not a list.');
    }
    return result
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getFriendsPlaceVisits() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Sign in to load friends’ place visits.');
    }
    final result = await client.rpc('get_friends_place_visits');
    if (result is! List) {
      throw const FormatException(
        'Friends’ place visits response was not a list.',
      );
    }
    return result
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFollowingActivity({
    int limit = 50,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final startedAt = DateTime.now();
    return runFollowingActivitySafely(() async {
      final result = await client.rpc(
        'get_following_activity',
        params: {'p_limit': limit},
      );
      if (result is! List) {
        throw const FormatException('Activity feed response was not a list.');
      }
      final rows = result
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      final currentUser = client.auth.currentUser;
      return filterOtherUsersActivity(
        rows,
        currentUser?.id ?? '',
        currentUsername:
            currentUser?.userMetadata?['username']?.toString() ?? '',
        currentDisplayName:
            currentUser?.userMetadata?['full_name']?.toString() ?? '',
      );
    }, startedAt: startedAt);
  }

  static Future<List<Map<String, dynamic>>> runFollowingActivitySafely(
    Future<List<Map<String, dynamic>>> Function() request, {
    DateTime? startedAt,
  }) async {
    try {
      return await request().timeout(const Duration(seconds: 10));
    } on PostgrestException catch (error, stackTrace) {
      final elapsed = startedAt == null
          ? ''
          : ' elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms';
      debugPrint(
        'SupabaseService.fetchFollowingActivity failed: '
        'code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}$elapsed',
      );
      debugPrint('$stackTrace');
      if (isTransientSupabaseError(error)) return const [];
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint(
        'SupabaseService.fetchFollowingActivity timed out: '
        '$error\n$stackTrace',
      );
      return const [];
    } on SocketException catch (error, stackTrace) {
      debugPrint(
        'SupabaseService.fetchFollowingActivity network failure: '
        '$error\n$stackTrace',
      );
      return const [];
    } on FormatException catch (error, stackTrace) {
      debugPrint(
        'SupabaseService.fetchFollowingActivity parse error: '
        '${error.message}\n$stackTrace',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'SupabaseService.fetchFollowingActivity unexpected error: '
        '$error\n$stackTrace',
      );
      if (isTransientSupabaseError(error)) return const [];
      rethrow;
    }
  }

  Future<void> submitReport({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? targetContext,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is unavailable.');
    }
    final resolvedReporterId = resolveUuidUserId(reporterId);
    if (resolvedReporterId == null) {
      throw StateError('Sign in to submit reports.');
    }

    if (targetId.trim().isEmpty ||
        (targetContext != null &&
            (targetType != 'ai_message' || targetContext.trim().isEmpty)) ||
        !const {'place', 'user', 'review', 'ai_message'}.contains(targetType) ||
        !const {
          'Inappropriate content',
          'Spam',
          'Harassment',
          'False information',
          'Other',
        }.contains(reason)) {
      throw ArgumentError('Invalid report details.');
    }
    await client.from('reports').insert({
      'reporter_id': resolvedReporterId,
      'target_id': targetId.trim(),
      'target_type': targetType,
      'reason': reason,
      if (targetContext != null)
        'target_context': targetContext.trim().substring(
          0,
          targetContext.trim().length > 2000
              ? 2000
              : targetContext.trim().length,
        ),
    });
  }

  Future<Set<String>> fetchReportedPhotoIds() async {
    final client = _client;
    final userId = resolveUuidUserId(client?.auth.currentUser?.id);
    if (client == null || userId == null) return <String>{};
    final rows = await client
        .from('photo_reports')
        .select('photo_id')
        .eq('reporter_id', userId);
    return (rows as List)
        .map((row) => (row as Map)['photo_id'].toString())
        .toSet();
  }

  Future<void> submitPhotoReport({
    required String photoId,
    required String photoUrl,
    required String uploaderId,
    required String placeId,
    required String reason,
  }) async {
    final client = _client;
    final reporterId = resolveUuidUserId(client?.auth.currentUser?.id);
    final resolvedUploaderId = resolveUuidUserId(uploaderId);
    if (client == null || reporterId == null) {
      throw StateError('Sign in to report a photo.');
    }
    if (photoId.trim().isEmpty ||
        photoUrl.trim().isEmpty ||
        resolvedUploaderId == null ||
        placeId.trim().isEmpty ||
        reporterId == resolvedUploaderId ||
        !const {
          'Inappropriate content',
          'Not related to this place',
          'Offensive/Abuse',
          'Other',
        }.contains(reason)) {
      throw ArgumentError('Invalid photo report details.');
    }
    await client.from('photo_reports').insert({
      'photo_id': photoId,
      'photo_url': photoUrl,
      'uploader_id': resolvedUploaderId,
      'reporter_id': reporterId,
      'place_id': placeId,
      'reason': reason,
    });
  }

  Future<void> pushStats(GamificationStats stats) async {
    final client = _client;
    final userId = resolveUuidUserId(client?.auth.currentUser?.id);
    if (client == null || userId == null) return;
    try {
      await client.from('leaderboard').upsert({
        ...stats.toJson(),
        'user_id': userId,
      });
    } catch (e) {
      _logError('pushStats', e);
    }
  }

  Future<GamificationStats?> pullStats(String userId) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return null;
    try {
      final res = await client
          .from('leaderboard')
          .select(
            'user_id,user_name,avatar_color_hex,total_points,places_visited,'
            'reviews_posted,photos_uploaded,level,badges,current_streak,'
            'longest_streak,total_visit_days',
          )
          .eq('user_id', resolvedUserId)
          .maybeSingle();
      if (res == null) return null;
      return GamificationStats.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      _logError('pullStats($userId)', e);
      return null;
    }
  }

  Future<bool> pushSavedPlace(String userId, PlaceModel place) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return false;
    try {
      await client.from('saved_places').upsert({
        'user_id': resolvedUserId,
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
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return false;
    try {
      await client
          .from('saved_places')
          .delete()
          .eq('user_id', resolvedUserId)
          .eq('place_id', placeId);
      return true;
    } catch (e) {
      _logError('deleteSavedPlace($userId, $placeId)', e);
      return false;
    }
  }

  Future<({bool ok, bool queued, PostgrestException? error})> registerCheckin(
    String userId,
    String placeId,
  ) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) {
      return (ok: false, queued: false, error: null);
    }
    final checkedInAt = DateTime.now().toUtc();
    final timestamp = checkedInAt.toIso8601String();

    Future<bool> queueCheckin() => SyncQueueService.instance.enqueueCheckin(
      userId: resolvedUserId,
      placeId: placeId,
      checkedInAt: checkedInAt,
    );

    if (!SyncQueueService.instance.isOnline) {
      final queued = await queueCheckin();
      return (
        ok: queued,
        queued: queued,
        error: queued
            ? null
            : PostgrestException(
                message: 'Check-in could not be saved to the offline queue.',
                code: 'offline_queue_unavailable',
                details: null,
                hint: null,
              ),
      );
    }
    try {
      await client.from('place_checkins').insert({
        'user_id': resolvedUserId,
        'place_id': placeId,
        'checked_in_at': timestamp,
      }).select();
      return (ok: true, queued: false, error: null);
    } on PostgrestException catch (e) {
      _logError('registerCheckin($resolvedUserId, $placeId)', e);
      return (ok: false, queued: false, error: e);
    } catch (e) {
      _logError('registerCheckin($resolvedUserId, $placeId)', e);
      final queued = await queueCheckin();
      return (
        ok: queued,
        queued: queued,
        error: queued
            ? null
            : PostgrestException(
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
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || placeId.isEmpty) return true;
    if (resolvedUserId == null) return false;
    try {
      await client
          .from('place_checkins')
          .delete()
          .eq('user_id', resolvedUserId)
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

  Future<List<DateTime>?> pullCheckinTimestamps(String userId) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return null;
    const pageSize = 1000;
    final timestamps = <DateTime>[];
    var offset = 0;
    try {
      while (true) {
        final rows = await client
            .from('place_checkins')
            .select('checked_in_at')
            .eq('user_id', resolvedUserId)
            .order('checked_in_at')
            .range(offset, offset + pageSize - 1);
        final page = rows as List;
        for (final row in page) {
          final value = (row as Map<String, dynamic>)['checked_in_at'];
          if (value is String) timestamps.add(DateTime.parse(value));
        }
        if (page.length < pageSize) break;
        offset += page.length;
      }
      return timestamps;
    } catch (e) {
      _logError('pullCheckinTimestamps($userId)', e);
      return null;
    }
  }

  Future<({int savedPlaces, int checkIns})> countUserRows(String userId) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) {
      return (savedPlaces: 0, checkIns: 0);
    }
    int saved = 0;
    int checkins = 0;
    try {
      final savedRes = await client
          .from('saved_places')
          .select('user_id')
          .eq('user_id', resolvedUserId)
          .count();
      saved = (savedRes as dynamic).count as int? ?? 0;
    } catch (e) {
      _logError('countUserRows(saved_places)', e);
    }
    try {
      final checkRes = await client
          .from('place_checkins')
          .select('user_id')
          .eq('user_id', resolvedUserId)
          .count();
      checkins = (checkRes as dynamic).count as int? ?? 0;
    } catch (e) {
      _logError('countUserRows(place_checkins)', e);
    }
    return (savedPlaces: saved, checkIns: checkins);
  }

  Future<List<PlaceModel>> pullSavedPlaces(String userId) async {
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return const [];
    try {
      final res = await client
          .from('saved_places')
          .select('place_data')
          .eq('user_id', resolvedUserId)
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
    final client = _client;
    final resolvedUserId = resolveUuidUserId(userId);
    if (client == null || resolvedUserId == null) return const [];
    try {
      final res = await client
          .from('saved_tours')
          .select('tour_data')
          .eq('user_id', resolvedUserId);
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
  /// [body] is a Gemini REST request body (contents + optional
  /// systemInstruction / generationConfig). The function only forwards a
  /// whitelist of it: `body['model']` must be an allowed model (otherwise
  /// `gemini-2.5-flash` is used) and `maxOutputTokens` is capped.
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
      if (response.body.contains('DAILY_LIMIT_EXCEEDED')) {
        throw Exception(
          'AI_DAILY_LIMIT_EXCEEDED: You have reached your daily limit, '
          'please come back tomorrow.',
        );
      }
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

  Stream<List<int>> aiProxyStream(
    Map<String, dynamic> body, {
    String? accessToken,
  }) async* {
    final client = clientOrNull;
    if (client == null) {
      throw Exception('Supabase client not initialized');
    }
    final token = accessToken ?? client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty) {
      throw Exception('Not signed in');
    }

    final request =
        http.Request(
            'POST',
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/ai-proxy'),
          )
          ..headers.addAll({
            'Content-Type': 'application/json',
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer $token',
          })
          ..body = jsonEncode(body);
    final httpClient = http.Client();
    try {
      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        if (response.statusCode == 429 &&
            responseBody.contains('DAILY_LIMIT_EXCEEDED')) {
          throw Exception(
            'AI_DAILY_LIMIT_EXCEEDED: You have reached your daily limit, '
            'please come back tomorrow.',
          );
        }
        throw Exception('ai-proxy HTTP ${response.statusCode}: $responseBody');
      }
      yield* response.stream;
    } finally {
      httpClient.close();
    }
  }

  /// Request full account + data deletion per Apple App Store and
  /// Google Play Store account-deletion requirements (PR #6). Calls
  /// the `delete-user-account` Edge Function which uses the service_role key
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
    final response = await client.functions.invoke(
      'delete-user-account',
      headers: {'Authorization': 'Bearer $token'},
      body: const <String, dynamic>{},
    );
    final result = response.data;
    if (response.status != 200 || result is! Map || result['ok'] != true) {
      throw const FormatException('Invalid account deletion response.');
    }
    return Map<String, dynamic>.from(result);
  }
}
