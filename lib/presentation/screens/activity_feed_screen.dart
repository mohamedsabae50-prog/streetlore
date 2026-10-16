import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_defaults.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/place_model.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/blocked_users_provider.dart';
import 'login_screen.dart';
import 'place_details_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/social_user_widgets.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  List<Map<String, dynamic>> _activities = const [];
  bool _loading = true;
  String? _error;
  String? _requestedUserId;
  String _filter = 'all';
  Map<String, SocialUser> _actorProfiles = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final userId = auth.isLoggedIn && !auth.isGuest ? auth.userId : '';
    if (_requestedUserId == userId) return;
    _requestedUserId = userId;
    if (userId.isEmpty) {
      _activities = const [];
      _loading = false;
      _error = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedUserId == userId) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activities = await SupabaseService.instance
          .fetchFollowingActivity();
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _actorProfiles = const {};
      });
      final actorIds = activities
          .map((activity) => activity['actor_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      try {
        final profiles = await SupabaseService.instance.getSocialUsers(
          actorIds,
        );
        if (mounted) {
          setState(() {
            _actorProfiles = {
              for (final profile in profiles) profile.userId: profile,
            };
          });
        }
      } catch (error, stackTrace) {
        debugPrint(
          'ActivityFeedScreen: actor profiles failed: $error\n$stackTrace',
        );
      }
    } catch (error, stackTrace) {
      // Always log to the console with full detail. When Sentry is wired
      // up (it is in main.dart) we also report the exception so it shows
      // up in the Sentry dashboard with the Postgrest code/message.
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
        .where((activity) {
          final actorId = activity['actor_id']?.toString() ?? '';
          return !blockedUsers.isBlocked(actorId);
        })
        .toList(growable: false);
    final filteredActivities = _filter == 'all'
        ? visibleActivities
        : visibleActivities
              .where((activity) => activity['event_type'] == _filter)
              .toList(growable: false);
    final needsSignIn = !auth.isLoggedIn || auth.isGuest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('feed_title')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('refresh'),
          ),
        ],
      ),
      body: needsSignIn
          ? _FeedMessage(
              text: context.tr('users_sign_in_required'),
              action: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: Text(context.tr('login_sign_in')),
              ),
            )
          : _loading && visibleActivities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _FeedMessage(
              text: _error!,
              action: FilledButton.tonal(
                onPressed: _load,
                child: Text(context.tr('no_internet_retry')),
              ),
            )
          : visibleActivities.isEmpty
          ? _FeedMessage(text: context.tr('feed_empty'))
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _feedHeader(context, visibleActivities.length),
                  ),
                  SliverToBoxAdapter(child: _feedFilters(context)),
                  if (filteredActivities.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FeedMessage(
                        text: context.tr(
                          _filter == 'all' ? 'feed_empty' : 'feed_filter_empty',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: filteredActivities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
    final placeName = locale == 'ar'
        ? (activity['place_name_ar'] as String?) ??
              (activity['place_name'] as String?) ??
              (activity['title'] as String?) ??
              ''
        : (activity['place_name'] as String?) ??
              (activity['title'] as String?) ??
              '';
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (type != 'checkin' &&
                        ((activity['description'] as String?)?.isNotEmpty ??
                            false)) ...[
                      const SizedBox(height: 4),
                      Text(
                        activity['description'] as String,
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
          (activity['place_name'] as String?) ??
          (activity['title'] as String?) ??
          '',
      nameAr: activity['place_name_ar'] as String?,
      descriptionEn: '',
      imageUrl: (activity['place_image_url'] as String?) ?? '',
      rating: 0,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
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
