import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/supabase_service.dart';

class BlockedUsersProvider extends ChangeNotifier {
  static const _storageKey = 'blocked_users_v1';

  final Set<String> _blockedUserIds = {};
  String _userId = '';
  bool _initialized = false;

  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);
  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  Future<void> setUserId(String userId) async {
    if (_initialized && _userId == userId) return;
    _userId = userId;
    await _loadLocal();
    _initialized = true;
    final client = SupabaseService.instance.clientOrNull;
    final authenticatedId = client?.auth.currentUser?.id;
    if (authenticatedId == null || authenticatedId != userId) return;
    try {
      final rows = await client!
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('blocker_id', authenticatedId);
      if (_userId != userId) return;
      _blockedUserIds.addAll(
        (rows as List<dynamic>).map(
          (row) => (row as Map<String, dynamic>)['blocked_user_id'] as String,
        ),
      );
      await _saveLocal();
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('BlockedUsersProvider sync failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> blockUser(String blockedUserId) async {
    if (blockedUserId.isEmpty || blockedUserId == _userId) {
      throw ArgumentError.value(blockedUserId, 'blockedUserId');
    }
    if (_blockedUserIds.add(blockedUserId)) {
      await _saveLocal();
      notifyListeners();
    }
    final client = SupabaseService.instance.clientOrNull;
    final authenticatedId = client?.auth.currentUser?.id;
    if (authenticatedId == null || authenticatedId != _userId) return;
    try {
      await client!
          .from('blocked_users')
          .upsert(
            {'blocker_id': authenticatedId, 'blocked_user_id': blockedUserId},
            onConflict: 'blocker_id,blocked_user_id',
            ignoreDuplicates: true,
          );
    } catch (error, stackTrace) {
      debugPrint('BlockedUsersProvider.blockUser failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final client = SupabaseService.instance.clientOrNull;
    final authenticatedId = client?.auth.currentUser?.id;
    if (authenticatedId != null && authenticatedId == _userId) {
      try {
        await client!
            .from('blocked_users')
            .delete()
            .eq('blocker_id', authenticatedId)
            .eq('blocked_user_id', blockedUserId);
      } catch (error, stackTrace) {
        debugPrint(
          'BlockedUsersProvider.unblockUser failed: $error\n$stackTrace',
        );
        rethrow;
      }
    }
    if (_blockedUserIds.remove(blockedUserId)) {
      await _saveLocal();
      notifyListeners();
    }
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser);
    _blockedUserIds
      ..clear()
      ..addAll(
        raw == null
            ? const <String>[]
            : (jsonDecode(raw) as List<dynamic>).cast<String>(),
      );
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForUser, jsonEncode(_blockedUserIds.toList()));
  }

  String get _keyForUser =>
      '$_storageKey${_userId.isEmpty ? "guest" : _userId}';
}
