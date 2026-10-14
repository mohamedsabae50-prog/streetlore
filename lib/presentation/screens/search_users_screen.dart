import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';

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
  final Map<String, bool> _following = {};
  final Set<String> _updatingFollow = {};
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
          _following.clear();
          _isLoading = false;
          _error = null;
          _searched = false;
        });
      } else {
        _search();
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
        _following.clear();
        for (final user in users) {
          _following[user.userId] = user.isFollowing;
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

  Future<void> _toggleFollow(SocialUser user) async {
    final auth = context.read<AuthProvider>();
    final wasFollowing = _following[user.userId] ?? false;
    setState(() => _updatingFollow.add(user.userId));
    try {
      if (wasFollowing) {
        await SupabaseService.instance.unfollowUser(auth.userId, user.userId);
      } else {
        await SupabaseService.instance.followUser(auth.userId, user.userId);
      }
      if (mounted) setState(() => _following[user.userId] = !wasFollowing);
    } catch (error, stackTrace) {
      debugPrint('SearchUsersScreen: follow action failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('follow_action_failed'))),
      );
    } finally {
      if (mounted) setState(() => _updatingFollow.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final requiresSignIn =
        !AppConfig.supabaseEnabled || !auth.isLoggedIn || auth.isGuest;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('users_search_title'))),
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
                if (!_searched && _users.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.tr('users_suggested_title'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.error),
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
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.username.characters.isEmpty
                                ? '?'
                                : user.username.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          user.displayName.isEmpty
                              ? '@${user.username}'
                              : user.displayName,
                        ),
                        subtitle: Text('@${user.username}'),
                        trailing: OutlinedButton(
                          onPressed:
                              _updatingFollow.contains(user.userId) ||
                                  !_following.containsKey(user.userId)
                              ? null
                              : () => _toggleFollow(user),
                          child: _updatingFollow.contains(user.userId)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  context.tr(
                                    _following[user.userId] == true
                                        ? 'unfollow_user'
                                        : 'follow_user',
                                  ),
                                ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfileScreen(user: user),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
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
