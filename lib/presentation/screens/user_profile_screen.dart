import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/place_model.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'place_details_screen.dart';
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
  List<Map<String, dynamic>> _visitedPlaces = const [];
  bool _isLoadingVisits = true;
  String? _visitsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFollowState();
      if (mounted) _loadVisitedPlaces();
    });
  }

  Future<void> _loadVisitedPlaces() async {
    try {
      final visits = await SupabaseService.instance.getUserVisitedPlaces(
        widget.user.userId,
      );
      if (mounted) setState(() => _visitedPlaces = visits);
    } catch (error, stackTrace) {
      debugPrint(
        'UserProfileScreen: visited places failed: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() => _visitsError = context.tr('profile_visits_failed'));
      }
    } finally {
      if (mounted) setState(() => _isLoadingVisits = false);
    }
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
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
          const SizedBox(height: 24),
          Text(
            context.tr('profile_visited_places'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingVisits)
            const Center(child: CircularProgressIndicator())
          else if (_visitsError != null)
            Text(_visitsError!, style: const TextStyle(color: AppColors.error))
          else if (_visitedPlaces.isEmpty)
            Text(context.tr('profile_no_visits'))
          else
            ..._visitedPlaces.map((visit) => _VisitedPlaceCard(visit: visit)),
        ],
      ),
    );
  }
}

class _VisitedPlaceCard extends StatelessWidget {
  const _VisitedPlaceCard({required this.visit});

  final Map<String, dynamic> visit;

  @override
  Widget build(BuildContext context) {
    final place = PlaceModel.fromJson(visit);
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateTime.tryParse(visit['checked_in_at']?.toString() ?? '');
    final dateLabel = date == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
    final imageUrl = place.primaryImage.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
        leading: SizedBox(
          width: 64,
          height: 64,
          child: imageUrl.startsWith('https://') || imageUrl.startsWith('http://')
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.place_outlined),
                )
              : const Icon(Icons.place_outlined),
        ),
        title: Text(
          place.localizedName(locale),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: dateLabel.isEmpty ? null : Text(dateLabel),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaceDetailsScreen(place: place),
          ),
        ),
      ),
    );
  }
}
