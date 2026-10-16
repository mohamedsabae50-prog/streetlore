import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../data/models/social_user.dart';

class SquadMember {
  const SquadMember({required this.user, required this.isLeader});

  final SocialUser user;
  final bool isLeader;

  factory SquadMember.fromJson(Map<String, dynamic> json) => SquadMember(
    user: SocialUser.fromJson(json),
    isLeader: json['is_leader'] == true,
  );
}

class SquadSession {
  const SquadSession({
    required this.id,
    required this.joinCode,
    required this.createdBy,
    required this.memberCount,
    required this.expiresAt,
    this.members = const [],
  });

  final String id;
  final String joinCode;
  final String createdBy;
  final int memberCount;
  final DateTime? expiresAt;
  final List<SquadMember> members;
  bool get isActive => expiresAt == null || expiresAt!.isAfter(DateTime.now());

  factory SquadSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final joinCode = json['join_code'] as String?;
    final createdBy = json['created_by'] as String?;
    if (id == null || joinCode == null || createdBy == null) {
      throw const FormatException('Squad response is missing required fields.');
    }
    return SquadSession(
      id: id,
      joinCode: joinCode,
      createdBy: createdBy,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      members: json['members'] is List
          ? (json['members'] as List)
                .whereType<Map>()
                .map(
                  (member) =>
                      SquadMember.fromJson(Map<String, dynamic>.from(member)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class SquadProvider extends ChangeNotifier {
  SquadSession? _session;
  String _userId = '';
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  SquadSession? get session => _session?.isActive == true ? _session : null;
  bool get hasActiveSquad => session != null;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> setUserId(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _session = null;
    _loading = false;
    _loaded = false;
    _error = null;
    _generation++;
    notifyListeners();
    if (userId.isNotEmpty) await refresh();
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final generation = ++_generation;
    final client = SupabaseService.instance.clientOrNull;
    if (client == null) {
      _error = 'Supabase is unavailable.';
      _loaded = true;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await client.rpc('get_my_active_squad');
      if (generation != _generation || userId != _userId) return;
      _session = result == null
          ? null
          : SquadSession.fromJson(Map<String, dynamic>.from(result as Map));
      _loaded = true;
    } catch (error, stackTrace) {
      if (generation != _generation || userId != _userId) return;
      _error = 'Could not load your squad: $error';
      _loaded = true;
      debugPrint('SquadProvider.refresh failed: $error\n$stackTrace');
    } finally {
      if (generation == _generation && userId == _userId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<SquadSession> createSquad() async {
    final client = _requireAuthenticatedClient();
    _error = null;
    notifyListeners();
    try {
      final result = await client.rpc('create_squad');
      final session = SquadSession.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
      _session = session;
      notifyListeners();
      return session;
    } catch (error, stackTrace) {
      _error = 'Could not create a squad: $error';
      debugPrint('SquadProvider.createSquad failed: $error\n$stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<SquadSession> joinSquad(String code) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(normalizedCode)) {
      throw const FormatException('Enter a 4-6 digit squad code.');
    }
    final client = _requireAuthenticatedClient();
    _error = null;
    notifyListeners();
    try {
      final result = await client.rpc(
        'join_squad',
        params: {'p_join_code': normalizedCode},
      );
      final session = SquadSession.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
      _session = session;
      notifyListeners();
      return session;
    } catch (error, stackTrace) {
      _error = 'Could not join that squad: $error';
      debugPrint('SquadProvider.joinSquad failed: $error\n$stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> leaveSquad() async {
    final client = _requireAuthenticatedClient();
    _error = null;
    notifyListeners();
    try {
      await client.rpc('leave_squad');
      _session = null;
      notifyListeners();
    } catch (error, stackTrace) {
      _error = 'Could not leave the squad: $error';
      debugPrint('SquadProvider.leaveSquad failed: $error\n$stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  SupabaseClient _requireAuthenticatedClient() {
    final client = SupabaseService.instance.clientOrNull;
    if (_userId.isEmpty ||
        client == null ||
        client.auth.currentUser?.id != _userId) {
      throw StateError('Sign in to use squad sessions.');
    }
    return client;
  }
}
