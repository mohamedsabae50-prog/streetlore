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

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2) {
      setState(() {
        _users = const [];
        _searched = false;
        _error = context.tr('users_search_min_length');
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _searched = true;
    });
    try {
      final users = await SupabaseService.instance.searchUsers(query);
      if (!mounted) return;
      setState(() => _users = users);
    } catch (error, stackTrace) {
      debugPrint('SearchUsersScreen: search failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _users = const [];
        _error = context.tr('users_search_failed');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                else if (_searched && !_isLoading && _users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.tr('users_search_empty')),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.username.characters.first),
                        ),
                        title: Text('@${user.username}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
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
