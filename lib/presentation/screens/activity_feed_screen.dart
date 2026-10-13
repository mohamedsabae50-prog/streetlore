import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'login_screen.dart';

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
        Sentry.captureException(error, stackTrace: stackTrace).catchError(
          (_) => SentryId.empty(),
        ),
      );
      final hint = _feedErrorHint(error);
      if (mounted) {
        setState(() => _error = hint ?? context.tr('feed_load_failed'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Returns a short, actionable explanation when we recognise the cause.
  /// Otherwise the caller falls back to the generic "Could not load the
  /// activity feed" string.
  String? _feedErrorHint(Object error) {
    if (error is PostgrestException) {
      // 42501 = insufficient_privilege (RLS denied). Most common cause
      // after a missing migration: a feed table is missing a SELECT
      // policy for the authenticated role.
      if (error.code == '42501' || error.code == 'PGRST301') {
        return '${context.tr('feed_load_failed')}\n'
            '[Postgrest ${error.code}] ${error.message}';
      }
      // P0001 / 22023 are custom PL/pgSQL RAISE EXCEPTIONs the function
      // uses for "Authentication required" / validation errors.
      if (error.code == 'P0001' || error.code == '22023') {
        return error.message;
      }
    }
    return null;
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          '@${activity['actor_username'] ?? ''} $action',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (activity['title'] as String?) ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if ((activity['description'] as String?)?.isNotEmpty ?? false)
              Text(activity['description'] as String),
            if (occurredAt != null)
              Text(
                MaterialLocalizations.of(context).formatMediumDate(occurredAt),
                style: TextStyle(color: context.textSec, fontSize: 12),
              ),
          ],
        ),
        isThreeLine: true,
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
          const Icon(Icons.dynamic_feed_rounded, size: 56, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
