import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_defaults.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/activity_feed_filter.dart';
import '../../data/achievement_catalog.dart';
import '../../data/models/place_model.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/achievement_provider.dart';
import '../../logic/blocked_users_provider.dart';
import '../../logic/gamification_provider.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'place_details_screen.dart';
import 'suggest_place_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/social_user_widgets.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _activities = const [];
  List<Map<String, dynamic>> _notifications = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  bool _loading = true;
  String? _error;
  String? _requestedUserId;
  String _filter = 'all';
  bool _requestsExpanded = false;
  Map<String, SocialUser> _actorProfiles = const {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  List<Map<String, dynamic>> _deduplicateNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final seen = <String>{};
    return notifications
        .where((notification) {
          final type = notification['type']?.toString() ?? '';
          final actorId = notification['actor_id']?.toString() ?? '';
          final title = notification['title']?.toString().trim() ?? '';
          final body = notification['body']?.toString().trim() ?? '';
          final createdAt = DateTime.tryParse(
            notification['created_at']?.toString() ?? '',
          );
          final minute = createdAt == null
              ? notification['created_at']?.toString() ?? ''
              : '${createdAt.toUtc().year}-'
                    '${createdAt.toUtc().month}-'
                    '${createdAt.toUtc().day}-'
                    '${createdAt.toUtc().hour}-'
                    '${createdAt.toUtc().minute}';
          final metadata = notification['metadata'];
          final metadataMap = metadata is Map
              ? Map<String, dynamic>.from(metadata)
              : const <String, dynamic>{};
          final badgeKey = type == 'badge_unlocked'
              ? (metadataMap['badge_id'] ??
                            metadataMap['badgeId'] ??
                            metadataMap['badge_name'] ??
                            metadataMap['badgeName'])
                        ?.toString() ??
                    ''
              : '';
          final key = [type, actorId, badgeKey, title, body, minute].join('|');
          return seen.add(key);
        })
        .toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final userId = auth.isLoggedIn && !auth.isGuest ? auth.userId : '';
    if (_requestedUserId == userId) return;
    _requestedUserId = userId;
    unawaited(_notificationSubscription?.cancel());
    _notificationSubscription = null;
    if (userId.isEmpty) {
      _activities = const [];
      _notifications = const [];
      _loading = false;
      _error = null;
      return;
    }
    _notificationSubscription = SupabaseService.instance
        .watchNotifications(userId)
        ?.listen(
          (notifications) {
            if (!mounted || _requestedUserId != userId) return;
            final otherNotifications = filterOtherUsersActivity(
              notifications,
              userId,
              currentUsername: auth.username,
              currentDisplayName: auth.userName,
            );
            final oldNotificationIds = _notifications
                .map((notification) => notification['id']?.toString() ?? '')
                .toSet();
            final received = otherNotifications
                .where(
                  (notification) => !oldNotificationIds.contains(
                    notification['id']?.toString() ?? '',
                  ),
                )
                .toList(growable: false);
            final uniqueNotifications = _deduplicateNotifications(
              otherNotifications,
            );
            setState(() => _notifications = uniqueNotifications);
            unawaited(_loadNotificationActors(uniqueNotifications));
            if (received.any(
              (notification) => notification['type'] == 'friend_accepted',
            )) {
              unawaited(
                context.read<AchievementProvider>().refreshFriendCount(),
              );
            }
            if (received.any(
              (notification) => notification['type'] == 'badge_unlocked',
            )) {
              unawaited(
                _refreshRemoteStats(
                  context.read<GamificationProvider>(),
                  userId,
                ),
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'ActivityFeedScreen: notification stream failed: '
              '$error\n$stackTrace',
            );
          },
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedUserId == userId) _load();
    });
  }

  Future<void> _load() async {
    final achievements = context.read<AchievementProvider>();
    final gamification = context.read<GamificationProvider>();
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.userId;
    final currentUsername = auth.username;
    final currentDisplayName = auth.userName;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activities = await SupabaseService.instance
          .fetchFollowingActivity();
      final notifications = _deduplicateNotifications(
        filterOtherUsersActivity(
          await SupabaseService.instance.fetchNotifications(),
          currentUserId,
          currentUsername: currentUsername,
          currentDisplayName: currentDisplayName,
        ),
      );
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _notifications = notifications;
      });
      if (notifications.any(
        (notification) => notification['type'] == 'friend_accepted',
      )) {
        await achievements.refreshFriendCount();
      }
      if (!mounted) return;
      if (notifications.any(
        (notification) => notification['type'] == 'badge_unlocked',
      )) {
        await _refreshRemoteStats(gamification, currentUserId);
      }
      if (!mounted) return;
      await _loadNotificationActors(notifications, activities: activities);
    } catch (error, stackTrace) {
      debugPrint('ActivityFeedScreen: load failed: $error\n$stackTrace');
      unawaited(
        Sentry.captureException(
          error,
          stackTrace: stackTrace,
        ).catchError((_) => SentryId.empty()),
      );
      final hint = _feedErrorHint(error);
      if (mounted) {
        setState(
          () => _error = hint ?? '${context.tr('feed_load_failed')}\n$error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshRemoteStats(
    GamificationProvider gamification,
    String userId,
  ) async {
    try {
      await gamification.bootstrapForUser(userId);
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: remote badge sync failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _loadNotificationActors(
    List<Map<String, dynamic>> notifications, {
    List<Map<String, dynamic>>? activities,
  }) async {
    final actorIds = <String>{
      ...notifications.map((item) => item['actor_id']?.toString() ?? ''),
      ...(activities ?? _activities).map(
        (item) => item['actor_id']?.toString() ?? '',
      ),
    }..removeWhere((id) => id.isEmpty);
    final auth = context.read<AuthProvider>();
    final ownActor = actorIds.remove(auth.userId)
        ? SocialUser(
            userId: auth.userId,
            username: auth.username,
            displayName: auth.userName,
            avatarUrl: auth.avatarUrl,
          )
        : null;
    if (actorIds.isEmpty && ownActor == null) return;
    try {
      final profiles = actorIds.isEmpty
          ? const <SocialUser>[]
          : await SupabaseService.instance.getSocialUsers(
              actorIds.toList(growable: false),
            );
      if (!mounted) return;
      setState(() {
        _actorProfiles = {
          for (final profile in profiles) profile.userId: profile,
          if (ownActor != null) ownActor.userId: ownActor,
        };
      });
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: actor profiles failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _respondToNotification(
    Map<String, dynamic> notification, {
    required bool accept,
  }) async {
    final actorId = notification['actor_id']?.toString() ?? '';
    final id = notification['id']?.toString() ?? '';
    if (actorId.isEmpty || id.isEmpty) return;
    final achievements = context.read<AchievementProvider>();
    try {
      await SupabaseService.instance.respondToFriendRequest(
        actorId,
        accept: accept,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: friend request response failed: '
        '$error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('friend_action_failed'))),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map(
            (item) => item['id'] == id
                ? {...item, 'read_at': DateTime.now().toUtc().toIso8601String()}
                : item,
          )
          .toList(growable: false);
    });
    try {
      await SupabaseService.instance.markNotificationRead(id);
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: failed to mark responded request read: '
        '$error\n$stackTrace',
      );
    }
    await achievements.refreshFriendCount();
  }

  Future<void> _markNotificationRead(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString() ?? '';
    if (id.isEmpty || notification['read_at'] != null) return;
    try {
      await SupabaseService.instance.markNotificationRead(id);
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: mark notification read failed: '
        '$error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Builds an on-screen diagnostic that ALWAYS includes the raw error so
  /// the exact Postgrest code / message is visible on the phone (same
  /// behaviour as the leaderboard screen).
  String? _feedErrorHint(Object error) {
    if (error is PostgrestException) {
      final buffer = StringBuffer()
        ..writeln(context.tr('feed_load_failed'))
        ..writeln('[Postgrest ${error.code ?? '-'}] ${error.message}');
      if (error.details != null && '${error.details}'.isNotEmpty) {
        buffer.writeln('details: ${error.details}');
      }
      if (error.hint != null && error.hint!.isNotEmpty) {
        buffer.writeln('hint: ${error.hint}');
      }
      return buffer.toString().trim();
    }
    return '${context.tr('feed_load_failed')}\n$error';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final blockedUsers = context.watch<BlockedUsersProvider>();
    final visibleActivities = _activities
        .where(
          (activity) =>
              !blockedUsers.isBlocked(activity['actor_id']?.toString() ?? ''),
        )
        .toList(growable: false);
    final otherUsersActivities = filterOtherUsersActivity(
      visibleActivities,
      auth.userId,
      currentUsername: auth.username,
      currentDisplayName: auth.userName,
    );
    final otherUsersNotifications = filterOtherUsersActivity(
      _notifications,
      auth.userId,
      currentUsername: auth.username,
      currentDisplayName: auth.userName,
    );
    final filteredActivities = _filter == 'all'
        ? otherUsersActivities
        : otherUsersActivities
              .where((activity) => activity['event_type'] == _filter)
              .toList(growable: false);
    final needsSignIn = !auth.isLoggedIn || auth.isGuest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('feed_title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('hub_community')),
            Tab(text: context.tr('hub_leaderboard')),
            Tab(text: context.tr('hub_badges')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('refresh'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          needsSignIn
              ? _FeedMessage(
                  text: context.tr('users_sign_in_required'),
                  action: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                    ),
                    child: Text(context.tr('login_sign_in')),
                  ),
                )
              : _loading &&
                    otherUsersActivities.isEmpty &&
                    otherUsersNotifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _FeedMessage(
                  text: _error!,
                  action: FilledButton.tonal(
                    onPressed: _load,
                    child: Text(context.tr('no_internet_retry')),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (otherUsersNotifications.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _requestsBanner(
                            context,
                            otherUsersNotifications,
                          ),
                        ),
                      if (_requestsExpanded &&
                          otherUsersNotifications.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          sliver: SliverList.separated(
                            itemCount: otherUsersNotifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final notification =
                                  otherUsersNotifications[index];
                              final actorId =
                                  notification['actor_id']?.toString() ?? '';
                              return _NotificationCard(
                                notification: notification,
                                actor: _actorProfiles[actorId],
                                onAccept: () => _respondToNotification(
                                  notification,
                                  accept: true,
                                ),
                                onDecline: () => _respondToNotification(
                                  notification,
                                  accept: false,
                                ),
                                onTap: notification['type'] == 'friend_request'
                                    ? () {}
                                    : () => _markNotificationRead(notification),
                              );
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SuggestPlaceScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.lightbulb_outline),
                              label: Text(
                                context.tr('feed_suggest_hidden_gem'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _feedHeader(context, filteredActivities.length),
                      ),
                      SliverToBoxAdapter(child: _feedFilters(context)),
                      if (filteredActivities.isEmpty &&
                          otherUsersNotifications.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _FeedMessage(
                            text: context.tr(
                              _filter == 'all'
                                  ? 'feed_empty'
                                  : 'feed_filter_empty',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: filteredActivities.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final activity = filteredActivities[index];
                              return _ActivityCard(
                                activity: activity,
                                actor:
                                    _actorProfiles[activity['actor_id']
                                        ?.toString()],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
          LeaderboardScreen(
            embedded: true,
            onShowBadges: () => _tabController.animateTo(2),
          ),
          const AchievementsScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _requestsBanner(
    BuildContext context,
    List<Map<String, dynamic>> notifications,
  ) {
    final requests = notifications
        .where(
          (notification) =>
              notification['type'] == 'friend_request' &&
              notification['read_at'] == null,
        )
        .length;
    final summary = requests > 0
        ? context.tr('feed_friend_requests_summary', {'count': '$requests'})
        : context.tr('feed_notifications_summary', {
            'count': '${notifications.length}',
          });
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _requestsExpanded = !_requestsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      color: context.textPri,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _requestsExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: context.textSec,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedHeader(BuildContext context, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('feed_header_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.textPri,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('feed_header_subtitle'),
                style: TextStyle(color: context.textSec, fontSize: 13),
              ),
            ],
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
            ),
            child: Text(
              '$count ${context.tr('feed_updates')}',
              style: TextStyle(
                color: context.textPri,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _feedFilters(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final filter in const ['all', 'checkin', 'badge', 'suggestion'])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(context.tr('feed_filter_$filter')),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
          ),
      ],
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final SocialUser? actor;

  const _ActivityCard({required this.activity, required this.actor});

  @override
  Widget build(BuildContext context) {
    final type = activity['event_type'] as String? ?? '';
    final icon = switch (type) {
      'checkin' => Icons.place_rounded,
      'badge' => Icons.workspace_premium_rounded,
      'suggestion' => Icons.auto_awesome_rounded,
      _ => Icons.notifications_rounded,
    };
    final action = switch (type) {
      'checkin' => context.tr('feed_action_checkin'),
      'badge' => context.tr('feed_action_badge'),
      'suggestion' => context.tr('feed_action_suggestion'),
      _ => '',
    };
    final occurredAt = DateTime.tryParse(
      activity['occurred_at'] as String? ?? '',
    );
    final place = _activityPlace(activity);
    final locale = Localizations.localeOf(context).languageCode;
    final localizedPlaceName = _localizedField(
      activity,
      locale,
      'place_name_en',
      'place_name_ar',
      fallbackKeys: locale == 'ar'
          ? const ['title_ar', 'place_name', 'title']
          : const ['title_en', 'place_name', 'title'],
    );
    final placeName = type == 'badge'
        ? _resolveBadgeText(
            context,
            activity['badge_name'] ??
                activity['badge_title'] ??
                localizedPlaceName,
          )
        : localizedPlaceName;
    final localizedDescription = _localizedField(
      activity,
      locale,
      'description_en',
      'description_ar',
      fallbackKeys: const ['description'],
    );
    final activityDescription = type == 'badge'
        ? _resolveBadgeText(
            context,
            activity['badge_description'] ??
                activity['description'] ??
                localizedDescription,
            description: true,
          )
        : localizedDescription;
    final textDirection = locale == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;
    final actorName =
        (activity['actor_display_name'] as String?)?.trim().isNotEmpty == true
        ? (activity['actor_display_name'] as String).trim()
        : '@${activity['actor_username'] ?? 'explorer'}';
    final timestamp = occurredAt == null
        ? null
        : '${MaterialLocalizations.of(context).formatMediumDate(occurredAt)} '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))}';
    final title = actor?.displayName.trim().isNotEmpty == true
        ? actor!.displayName.trim()
        : actorName;
    final activityTime = occurredAt == null
        ? timestamp
        : _relativeTimestamp(context, occurredAt);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        onTap: place == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailsScreen(place: place),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openActorProfile(context),
                child: actor == null
                    ? CircleAvatar(
                        radius: 23,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          actorName.characters.first.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : SocialUserAvatar(user: actor!, radius: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        InkWell(
                          onTap: () => _openActorProfile(context),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: context.textPri,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _ActivityKindChip(
                          label: action,
                          icon: icon,
                          type: type,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      placeName,
                      textDirection: textDirection,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (type != 'checkin' &&
                        activityDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        activityDescription,
                        textDirection: textDirection,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.textSec, fontSize: 12),
                      ),
                    ],
                    if (activityTime != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: context.textSec,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activityTime,
                            style: TextStyle(
                              color: context.textSec,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _activityThumbnail(
                activity['place_image_url'] as String?,
                icon,
                activity['place_category']?.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _relativeTimestamp(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(localDate.year, localDate.month, localDate.day);
    final dayDifference = today.difference(eventDay).inDays;
    if (dayDifference == 0) {
      return '${context.tr('feed_today')} · '
          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(localDate))}';
    }
    if (dayDifference == 1) return context.tr('feed_yesterday');
    return MaterialLocalizations.of(context).formatMediumDate(localDate);
  }

  Future<void> _openActorProfile(BuildContext context) async {
    if (actor != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UserProfileScreen(user: actor!),
        ),
      );
      return;
    }
    final userId = activity['actor_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      final user = await SupabaseService.instance.getSocialUser(userId);
      if (user == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ActivityFeedScreen: profile load failed: $error\n$stackTrace',
      );
    }
  }

  PlaceModel? _activityPlace(Map<String, dynamic> activity) {
    final id = activity['place_id']?.toString() ?? '';
    final lat = activity['place_lat'];
    final lng = activity['place_lng'];
    if (id.isEmpty || lat is! num || lng is! num) return null;
    return PlaceModel(
      id: id,
      nameEn:
          (activity['place_name_en'] as String?) ??
          (activity['place_name'] as String?) ??
          (activity['title_en'] as String?) ??
          (activity['title'] as String?) ??
          '',
      nameAr:
          (activity['place_name_ar'] as String?) ??
          activity['title_ar'] as String?,
      descriptionEn:
          (activity['description_en'] as String?) ??
          (activity['description'] as String?) ??
          '',
      descriptionAr: activity['description_ar'] as String?,
      imageUrl: (activity['place_image_url'] as String?) ?? '',
      rating: 0,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
  }

  String _localizedField(
    Map<String, dynamic> value,
    String locale,
    String enKey,
    String arKey, {
    required List<String> fallbackKeys,
  }) {
    final localized = value[locale == 'ar' ? arKey : enKey];
    if (localized is String && localized.trim().isNotEmpty) {
      return localized.trim();
    }
    for (final key in fallbackKeys) {
      final fallback = value[key];
      if (fallback is String && fallback.trim().isNotEmpty) {
        return fallback.trim();
      }
    }
    return '';
  }

  Widget _activityThumbnail(String? imageUrl, IconData icon, String? category) {
    final url = imageUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 54,
          height: 62,
          cacheWidth: 108,
          cacheHeight: 108,
          fit: BoxFit.cover,
          headers: streetloreImageHeaders,
          errorBuilder: (_, _, _) =>
              CategoryImageFallback(category: category, width: 54, height: 62),
        ),
      );
    }
    return CategoryImageFallback(category: category, width: 54, height: 62);
  }
}

String _resolveBadgeText(
  BuildContext context,
  Object? raw, {
  bool description = false,
}) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return '';

  AchievementDefinition? definition = AchievementCatalog.byId(
    AchievementCatalog.canonicalId(value),
  );
  if (definition == null) {
    for (final candidate in AchievementCatalog.all) {
      if (candidate.nameKey == value || candidate.descKey == value) {
        definition = candidate;
        break;
      }
    }
  }
  if (definition != null) {
    return context.tr(description ? definition.descKey : definition.nameKey);
  }

  if (value.startsWith('ach_') ||
      value.startsWith('badge_') ||
      value.contains('_')) {
    final translated = context.tr(value);
    if (translated != value) return translated;
    final readable = value
        .replaceFirst(RegExp(r'^(ach|badge)_'), '')
        .replaceFirst(RegExp(r'_(name|desc)$'), '')
        .replaceAll('_', ' ');
    return readable
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
  return value;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.actor,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
  });

  final Map<String, dynamic> notification;
  final SocialUser? actor;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = notification['type']?.toString() ?? '';
    final pending = type == 'friend_request' && notification['read_at'] == null;
    final metadata = notification['metadata'];
    final metadataMap = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};
    final badgeId =
        (metadataMap['badge_id'] ??
                metadataMap['badgeId'] ??
                notification['badge_id'])
            ?.toString();
    final badgeName = _resolveBadgeText(
      context,
      badgeId ??
          metadataMap['badge_name'] ??
          metadataMap['badgeName'] ??
          metadataMap['name'] ??
          notification['badge_name'],
    );
    final actorName = actor?.displayName.trim().isNotEmpty == true
        ? actor!.displayName.trim()
        : '@${actor?.username ?? 'explorer'}';
    final title = switch (type) {
      'friend_request' => context.tr('notification_friend_request', {
        'name': actorName,
      }),
      'friend_accepted' => context.tr('notification_friend_accepted', {
        'name': actorName,
      }),
      'badge_unlocked' =>
        context.tr('notification_badge_unlocked', {'name': actorName}) +
            (badgeName.isEmpty ? '' : ' · $badgeName'),
      _ => notification['title']?.toString() ?? '',
    };
    final createdAt = DateTime.tryParse(
      notification['created_at']?.toString() ?? '',
    );
    final timestamp = createdAt == null
        ? ''
        : '${MaterialLocalizations.of(context).formatMediumDate(createdAt.toLocal())} '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(createdAt.toLocal()))}';
    final unread = notification['read_at'] == null;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: unread
          ? AppColors.primary.withValues(alpha: 0.055)
          : context.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.35)
              : context.borderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (actor != null)
                SocialUserAvatar(user: actor!, radius: 22)
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.notifications_rounded),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPri,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (timestamp.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        timestamp,
                        style: TextStyle(color: context.textSec, fontSize: 11),
                      ),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: onAccept,
                            child: Text(context.tr('friend_accept')),
                          ),
                          OutlinedButton(
                            onPressed: onDecline,
                            child: Text(context.tr('friend_decline')),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityKindChip extends StatelessWidget {
  const _ActivityKindChip({
    required this.label,
    required this.icon,
    required this.type,
  });

  final String label;
  final IconData icon;
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'badge' => AppColors.ratingGold,
      'suggestion' => const Color(0xFF7C3AED),
      _ => AppColors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final String text;
  final Widget? action;

  const _FeedMessage({required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.dynamic_feed_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
