import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/image_defaults.dart';
import '../../data/models/place_model.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/achievement_provider.dart';
import '../../logic/blocked_users_provider.dart';
import 'place_details_screen.dart';
import '../widgets/report_content_sheet.dart';
import '../widgets/social_user_widgets.dart';

class UserProfileScreen extends StatefulWidget {
  final SocialUser user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? _friendshipState;
  bool _isUpdating = false;
  late int _friendsCount;
  String? _error;
  List<Map<String, dynamic>> _visitedPlaces = const [];
  bool _isLoadingVisits = true;
  String? _visitsError;

  @override
  void initState() {
    super.initState();
    _friendsCount = widget.user.friendsCount;
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
      final state = await SupabaseService.instance.getFriendshipState(
        widget.user.userId,
      );
      if (mounted) setState(() => _friendshipState = state);
    } catch (error, stackTrace) {
      debugPrint('UserProfileScreen: follow state failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = context.tr('follow_action_failed'));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleFollow() async {
    final state = _friendshipState ?? 'none';
    final achievements = context.read<AchievementProvider>();
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      switch (state) {
        case 'accepted':
          await SupabaseService.instance.removeFriend(widget.user.userId);
          break;
        case 'outgoing':
          await SupabaseService.instance.cancelFriendRequest(
            widget.user.userId,
          );
          break;
        case 'incoming':
          await SupabaseService.instance.respondToFriendRequest(
            widget.user.userId,
            accept: true,
          );
          await achievements.refreshFriendCount();
          break;
        default:
          await SupabaseService.instance.sendFriendRequest(widget.user.userId);
      }
      final updatedState = await SupabaseService.instance.getFriendshipState(
        widget.user.userId,
      );
      if (mounted) {
        setState(() {
          if (state == 'accepted' && updatedState != 'accepted') {
            _friendsCount = (_friendsCount - 1).clamp(0, 1 << 30);
          } else if (state == 'incoming' && updatedState == 'accepted') {
            _friendsCount++;
          }
          _friendshipState = updatedState;
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'UserProfileScreen: follow action failed: $error\n$stackTrace',
      );
      if (mounted) setState(() => _error = context.tr('follow_action_failed'));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleBlock() async {
    final blockedUsers = context.read<BlockedUsersProvider>();
    final isBlocked = blockedUsers.isBlocked(widget.user.userId);
    if (!isBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('block_user_title')),
          content: Text(context.tr('block_user_confirmation')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('block_user')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _isUpdating = true);
    try {
      if (isBlocked) {
        await blockedUsers.unblockUser(widget.user.userId);
      } else {
        await blockedUsers.blockUser(widget.user.userId);
      }
    } catch (error, stackTrace) {
      debugPrint('UserProfileScreen: block action failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = context.tr('block_user_failed'));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final blockedUsers = context.watch<BlockedUsersProvider>();
    final isBlocked = blockedUsers.isBlocked(widget.user.userId);
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
          if (canFollow && widget.user.userId != auth.userId)
            IconButton(
              tooltip: context.tr(isBlocked ? 'unblock_user' : 'block_user'),
              onPressed: _isUpdating ? null : _toggleBlock,
              icon: Icon(
                isBlocked ? Icons.check_circle_outline : Icons.block_rounded,
              ),
            ),
        ],
      ),
      body: isBlocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('blocked_profile_hidden'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      SocialUserAvatar(user: widget.user, radius: 42),
                      const SizedBox(height: 16),
                      Text(
                        widget.user.displayName.isEmpty
                            ? '@${widget.user.username}'
                            : widget.user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (widget.user.displayName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '@${widget.user.username}',
                          style: TextStyle(color: context.textSec),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SocialFriendCount(friends: _friendsCount),
                      const SizedBox(height: 10),
                      SocialBadges(badges: widget.user.badges),
                      const SizedBox(height: 24),
                      if (canFollow)
                        FilledButton.icon(
                          onPressed: _isUpdating || _friendshipState == null
                              ? null
                              : _toggleFollow,
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _friendshipState == 'accepted'
                                      ? Icons.person_remove_alt_1_rounded
                                      : _friendshipState == 'outgoing'
                                      ? Icons.hourglass_top_rounded
                                      : _friendshipState == 'incoming'
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                ),
                          label: Text(
                            context.tr(switch (_friendshipState) {
                              'accepted' => 'remove_friend',
                              'outgoing' => 'cancel_friend_request',
                              'incoming' => 'accept_friend_request',
                              _ => 'send_friend_request',
                            }),
                          ),
                        )
                      else
                        Text(context.tr('users_sign_in_required')),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('profile_visited_places'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (_isLoadingVisits)
                  const Center(child: CircularProgressIndicator())
                else if (_visitsError != null)
                  Text(
                    _visitsError!,
                    style: const TextStyle(color: AppColors.error),
                  )
                else if (_visitedPlaces.isEmpty)
                  Text(context.tr('profile_no_visits'))
                else
                  ..._visitedPlaces.map(
                    (visit) => _VisitedPlaceCard(visit: visit),
                  ),
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
          child:
              imageUrl.startsWith('https://') || imageUrl.startsWith('http://')
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 128,
                  cacheHeight: 128,
                  headers: streetloreImageHeaders,
                  errorBuilder: (_, _, _) => CategoryImageFallback(
                    category: place.category,
                    width: 64,
                    height: 64,
                  ),
                )
              : CategoryImageFallback(
                  category: place.category,
                  width: 64,
                  height: 64,
                ),
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
