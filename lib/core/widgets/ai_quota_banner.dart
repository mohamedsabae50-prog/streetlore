import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../services/supabase_service.dart';

class AiQuotaBanner extends StatefulWidget {
  const AiQuotaBanner({super.key});

  @override
  State<AiQuotaBanner> createState() => AiQuotaBannerState();
}

class AiQuotaBannerState extends State<AiQuotaBanner> {
  Map<String, dynamic>? _status;
  String? _error;
  Timer? _resetTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (SupabaseService.instance.isLive) refresh();
  }

  Future<void> refresh() async {
    _resetTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await SupabaseService.instance.fetchAiQuotaStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      final resetAt = DateTime.parse(status['next_reset_at'] as String);
      final untilReset = resetAt.difference(DateTime.now());
      final delay = untilReset <= Duration.zero
          ? const Duration(seconds: 1)
          : untilReset;
      _resetTimer = Timer(delay, refresh);
    } catch (error, stackTrace) {
      debugPrint('AiQuotaBanner.refresh failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      _resetTimer = Timer(const Duration(minutes: 1), refresh);
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.instance.isLive) {
      return const SizedBox.shrink();
    }
    if (context.select<AuthProvider, bool>((auth) => auth.isAdmin)) {
      return const SizedBox.shrink();
    }

    final message = _loading
        ? context.tr('ai_quota_loading')
        : _error != null
        ? context.tr('ai_quota_unavailable')
        : context.tr('ai_quota_remaining', {
            'remaining': '${_status!['remaining']}',
            'limit': '${_status!['daily_limit']}',
          });
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 12)),
                if (!_loading && _error == null)
                  Text(
                    context.tr('ai_quota_reset_utc'),
                    style: const TextStyle(fontSize: 10),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
          if (_error != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.tr('ai_quota_retry'),
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class AiDailyLimitCard extends StatelessWidget {
  const AiDailyLimitCard({super.key, required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('ai_daily_limit_title'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(context.tr('ai_daily_limit_body')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(context.tr('ai_upgrade_pro')),
            ),
          ],
        ),
      ),
    );
  }
}
