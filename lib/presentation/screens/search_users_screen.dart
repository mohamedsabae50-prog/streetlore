import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/achievement_provider.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/social_user_widgets.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _queryController = TextEditingController();
  List<SocialUser> _users = const [];
  bool _isLoading = false;
  String? _error;
  bool _searched = false;
  final Map<String, String> _relationships = {};
  final Set<String> _updatingRelationship = {};
  final Set<String> _updatingPrivacy = {};
  List<SocialUser> _friends = const [];
  List<SocialUser> _incomingRequests = const [];
  List<SocialUser> _outgoingRequests = const [];
  Map<String, String> _incomingRequestIds = const {};
  Map<String, bool> _friendPrivacy = const {};
  bool _relationshipsLoading = false;
  String? _relationshipError;
  int _requestGeneration = 0;
  String? _requestedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final userId = auth.isLoggedIn && !auth.isGuest ? auth.userId : '';
    if (_requestedUserId == userId) return;
    _requestedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedUserId != userId) return;
      if (userId.isEmpty) {
        ++_requestGeneration;
        setState(() {
          _users = const [];
          _relationships.clear();
          _friends = const [];
          _incomingRequests = const [];
          _outgoingRequests = const [];
          _isLoading = false;
          _error = null;
          _searched = false;
        });
      } else {
        _search();
        unawaited(_loadRelationships());
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isNotEmpty && query.length < 2) {
      ++_requestGeneration;
      setState(() {
        _isLoading = false;
        _error = context.tr('users_search_min_length');
      });
      return;
    }
    final generation = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _searched = query.isNotEmpty;
    });
    try {
      final users = await SupabaseService.instance.searchUsers(query);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _users = users;
        for (final user in users) {
          _relationships.putIfAbsent(
            user.userId,
            () => user.isFollowing ? 'accepted' : 'none',
          );
        }
      });
    } catch (error, stackTrace) {
      debugPrint('SearchUsersScreen: search failed: $error\n$stackTrace');
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _users = const [];
        _error = context.tr('users_search_failed');
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRelationships() async {
    if (!mounted) return;
    setState(() {
      _relationshipsLoading = true;
      _relationshipError = null;
    });
    try {
      final rows = await SupabaseService.instance.fetchFriendships();
      if (!mounted) return;
      final userId = context.read<AuthProvider>().userId;
      final incomingIds = <String, String>{};
      final outgoingIds = <String, String>{};
      final friendIds = <String>{};
      for (final row in rows) {
        final requester = row['requester_id']?.toString() ?? '';
        final recipient = row['recipient_id']?.toString() ?? '';
        final status = row['status']?.toString() ?? '';
        final requestId = row['id']?.toString() ?? '';
        if (status == 'accepted') {
          friendIds.add(requester == userId ? recipient : requester);
        } else if (status == 'pending' && recipient == userId) {
          incomingIds[requester] = requestId;
        } else if (status == 'pending' && requester == userId) {
          outgoingIds[recipient] = requestId;
        }
      }
      final allIds = {...friendIds, ...incomingIds.keys, ...outgoingIds.keys};
      final profiles = await SupabaseService.instance.getSocialUsers(
        allIds.toList(growable: false),
      );
      final byId = {for (final profile in profiles) profile.userId: profile};
      final privacy = await SupabaseService.instance
          .fetchFriendPrivacySettings();
      if (!mounted) return;
      setState(() {
        _friends = friendIds
            .map((id) => byId[id])
            .whereType<SocialUser>()
            .toList(growable: false);
        _incomingRequests = incomingIds.keys
            .map((id) => byId[id])
            .whereType<SocialUser>()
            .toList(growable: false);
        _outgoingRequests = outgoingIds.keys
            .map((id) => byId[id])
            .whereType<SocialUser>()
            .toList(growable: false);
        _incomingRequestIds = incomingIds;
        _friendPrivacy = privacy;
        _relationships
          ..clear()
          ..addEntries(friendIds.map((id) => MapEntry(id, 'accepted')))
          ..addEntries(incomingIds.keys.map((id) => MapEntry(id, 'incoming')))
          ..addEntries(outgoingIds.keys.map((id) => MapEntry(id, 'outgoing')));
      });
    } catch (error, stackTrace) {
      debugPrint(
        'SearchUsersScreen: relationship load failed: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() => _relationshipError = context.tr('friends_load_failed'));
      }
    } finally {
      if (mounted) setState(() => _relationshipsLoading = false);
    }
  }

  Future<void> _actOnRelationship(SocialUser user) async {
    final status = _relationships[user.userId] ?? 'none';
    if (status == 'incoming') return;
    setState(() => _updatingRelationship.add(user.userId));
    try {
      switch (status) {
        case 'accepted':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.tr('remove_friend_title')),
              content: Text(context.tr('remove_friend_confirmation')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr('remove_friend')),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await SupabaseService.instance.removeFriend(user.userId);
          break;
        case 'outgoing':
          await SupabaseService.instance.cancelFriendRequest(user.userId);
          break;
        default:
          await SupabaseService.instance.sendFriendRequest(user.userId);
      }
      await _loadRelationships();
    } catch (error, stackTrace) {
      debugPrint(
        'SearchUsersScreen: friend action failed: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('friend_action_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingRelationship.remove(user.userId));
    }
  }

  Future<void> _respondToRequest(SocialUser user, bool accept) async {
    final requestId = _incomingRequestIds[user.userId];
    if (requestId == null) return;
    final achievements = context.read<AchievementProvider>();
    setState(() => _updatingRelationship.add(user.userId));
    try {
      await SupabaseService.instance.respondToFriendRequest(
        user.userId,
        accept: accept,
      );
      if (accept) {
        await achievements.refreshFriendCount();
      }
      await _loadRelationships();
    } catch (error, stackTrace) {
      debugPrint(
        'SearchUsersScreen: request response failed: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('friend_action_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingRelationship.remove(user.userId));
    }
  }

  Future<void> _setFriendPrivacy(SocialUser friend, bool enabled) async {
    setState(() => _updatingPrivacy.add(friend.userId));
    try {
      await SupabaseService.instance.setFriendLocationActivitySharing(
        friend.userId,
        enabled,
      );
      if (mounted) {
        setState(() => _friendPrivacy[friend.userId] = enabled);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'SearchUsersScreen: friend privacy update failed: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('privacy_settings_save_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPrivacy.remove(friend.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final requiresSignIn =
        !AppConfig.supabaseEnabled || !auth.isLoggedIn || auth.isGuest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('users_search_title')),
        actions: [
          IconButton(
            onPressed: _relationshipsLoading
                ? null
                : () => unawaited(_loadRelationships()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('refresh'),
          ),
        ],
      ),
      body: requiresSignIn
          ? _SignInPrompt(
              onSignIn: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: context.tr('users_search_hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: _isLoading ? null : _search,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (_isLoading) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    children: [
                      if (_relationshipsLoading)
                        const LinearProgressIndicator(),
                      if (_relationshipError != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _relationshipError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      if (_incomingRequests.isNotEmpty) ...[
                        _sectionTitle(
                          context,
                          'incoming_friend_requests',
                          _incomingRequests.length,
                        ),
                        for (final user in _incomingRequests)
                          ListTile(
                            leading: SocialUserAvatar(user: user),
                            title: Text(
                              user.displayName.isEmpty
                                  ? '@${user.username}'
                                  : user.displayName,
                            ),
                            subtitle: Text('@${user.username}'),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: context.tr('accept_friend_request'),
                                  onPressed:
                                      _updatingRelationship.contains(
                                        user.userId,
                                      )
                                      ? null
                                      : () => _respondToRequest(user, true),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.success,
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('decline_friend_request'),
                                  onPressed:
                                      _updatingRelationship.contains(
                                        user.userId,
                                      )
                                      ? null
                                      : () => _respondToRequest(user, false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (_friends.isNotEmpty) ...[
                        _sectionTitle(
                          context,
                          'friends_list_title',
                          _friends.length,
                        ),
                        for (final user in _friends)
                          ListTile(
                            leading: SocialUserAvatar(user: user),
                            title: Text(
                              user.displayName.isEmpty
                                  ? '@${user.username}'
                                  : user.displayName,
                            ),
                            subtitle: Text(
                              context.tr('friend_location_activity_sharing'),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch.adaptive(
                                  value: _friendPrivacy[user.userId] ?? true,
                                  onChanged:
                                      _updatingPrivacy.contains(user.userId)
                                      ? null
                                      : (enabled) =>
                                            _setFriendPrivacy(user, enabled),
                                ),
                                IconButton(
                                  tooltip: context.tr('remove_friend'),
                                  onPressed:
                                      _updatingRelationship.contains(
                                        user.userId,
                                      )
                                      ? null
                                      : () => _actOnRelationship(user),
                                  icon: const Icon(
                                    Icons.person_remove_alt_1_rounded,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => UserProfileScreen(user: user),
                              ),
                            ),
                          ),
                      ],
                      if (_outgoingRequests.isNotEmpty) ...[
                        _sectionTitle(
                          context,
                          'sent_friend_requests',
                          _outgoingRequests.length,
                        ),
                        for (final user in _outgoingRequests)
                          ListTile(
                            leading: SocialUserAvatar(user: user),
                            title: Text(
                              user.displayName.isEmpty
                                  ? '@${user.username}'
                                  : user.displayName,
                            ),
                            subtitle: Text(
                              context.tr('friend_request_pending'),
                            ),
                            trailing: IconButton(
                              tooltip: context.tr('cancel_friend_request'),
                              onPressed:
                                  _updatingRelationship.contains(user.userId)
                                  ? null
                                  : () => _actOnRelationship(user),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        )
                      else if (!_isLoading && _users.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.tr(
                              _searched
                                  ? 'users_search_empty'
                                  : 'users_suggestions_empty',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_users.isNotEmpty)
                        _sectionTitle(
                          context,
                          _searched
                              ? 'users_search_results'
                              : 'users_suggested_title',
                          _users.length,
                        ),
                      for (final user in _users)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: SocialUserAvatar(user: user),
                          title: Text(
                            user.displayName.isEmpty
                                ? '@${user.username}'
                                : user.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@${user.username}'),
                              const SizedBox(height: 4),
                              SocialFriendCount(friends: user.friendsCount),
                              if (user.badges.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                SocialBadges(
                                  badges: user.badges,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          isThreeLine: true,
                          trailing: OutlinedButton(
                            onPressed:
                                _updatingRelationship.contains(user.userId) ||
                                    _relationshipsLoading ||
                                    (_relationships[user.userId] ?? 'none') ==
                                        'incoming'
                                ? null
                                : () => _actOnRelationship(user),
                            child: _updatingRelationship.contains(user.userId)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    context.tr(
                                      switch (_relationships[user.userId] ??
                                          'none') {
                                        'accepted' => 'remove_friend',
                                        'incoming' => 'incoming_request',
                                        'outgoing' => 'friend_request_pending',
                                        _ => 'send_friend_request',
                                      },
                                    ),
                                  ),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => UserProfileScreen(user: user),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String key, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Text(
      '${context.tr(key)} ($count)',
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;

  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            context.tr('users_sign_in_required'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onSignIn,
            child: Text(context.tr('login_sign_in')),
          ),
        ],
      ),
    ),
  );
}
