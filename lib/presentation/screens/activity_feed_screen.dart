import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_defaults.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'login_screen.dart';
import 'place_details_screen.dart';
import 'user_profile_screen.dart';

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
      if (mounted) setState(() => _activities = activities);
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
          : _loading && _activities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _FeedMessage(
              text: _error!,
              action: FilledButton.tonal(
                onPressed: _load,
                child: Text(context.tr('no_internet_retry')),
              ),
            )
          : _activities.isEmpty
          ? _FeedMessage(text: context.tr('feed_empty'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _activities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _ActivityCard(activity: _activities[index]),
              ),
            ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ActivityCard({required this.activity});

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
    return Card(
      child: ListTile(
        onTap: place == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailsScreen(place: place),
                ),
              ),
        leading: _activityThumbnail(
          activity['place_image_url'] as String?,
          icon,
          activity['place_category']?.toString(),
        ),
        title: Wrap(
          spacing: 4,
          children: [
            InkWell(
              onTap: () => _openActorProfile(context),
              child: Text(
                actorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              placeName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (type != 'checkin' &&
                ((activity['description'] as String?)?.isNotEmpty ?? false))
              Text(activity['description'] as String),
            if (timestamp != null)
              Text(
                timestamp,
                style: TextStyle(color: context.textSec, fontSize: 12),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _openActorProfile(BuildContext context) async {
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

  Widget _activityThumbnail(
    String? imageUrl,
    IconData icon,
    String? category,
  ) {
    final url = imageUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 54,
          height: 54,
          cacheWidth: 108,
          cacheHeight: 108,
          fit: BoxFit.cover,
          headers: streetloreImageHeaders,
          errorBuilder: (_, _, _) =>
              CategoryImageFallback(category: category, width: 54, height: 54),
        ),
      );
    }
    return CategoryImageFallback(
      category: category,
      width: 54,
      height: 54,
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
