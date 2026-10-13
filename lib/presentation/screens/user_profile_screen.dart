import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../widgets/report_content_sheet.dart';

class UserProfileScreen extends StatefulWidget {
  final SocialUser user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool? _isFollowing;
  bool _isUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFollowState();
    });
  }

  Future<void> _loadFollowState() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.isGuest || auth.userId.isEmpty) return;
    setState(() => _isUpdating = true);
    try {
      final following = await SupabaseService.instance.isFollowing(
        auth.userId,
        widget.user.userId,
      );
      if (mounted) setState(() => _isFollowing = following);
    } catch (error, stackTrace) {
      debugPrint('UserProfileScreen: follow state failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = context.tr('follow_action_failed'));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthProvider>();
    final wasFollowing = _isFollowing ?? false;
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      if (wasFollowing) {
        await SupabaseService.instance.unfollowUser(
          auth.userId,
          widget.user.userId,
        );
      } else {
        await SupabaseService.instance.followUser(
          auth.userId,
          widget.user.userId,
        );
      }
      if (mounted) setState(() => _isFollowing = !wasFollowing);
    } catch (error, stackTrace) {
      debugPrint(
        'UserProfileScreen: follow action failed: $error\n$stackTrace',
      );
      if (mounted) setState(() => _error = context.tr('follow_action_failed'));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canFollow =
        AppConfig.supabaseEnabled && auth.isLoggedIn && !auth.isGuest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('user_profile_title')),
        actions: [
          if (canFollow)
            IconButton(
              tooltip: context.tr('report_title'),
              onPressed: () => ReportContentSheet.show(
                context,
                targetId: widget.user.userId,
                targetType: 'user',
              ),
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  widget.user.username.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '@${widget.user.username}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              if (canFollow)
                FilledButton.icon(
                  onPressed: _isUpdating || _isFollowing == null
                      ? null
                      : _toggleFollow,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isFollowing == true
                              ? Icons.person_remove_alt_1_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                  label: Text(
                    context.tr(
                      _isFollowing == true ? 'unfollow_user' : 'follow_user',
                    ),
                  ),
                )
              else
                Text(context.tr('users_sign_in_required')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
