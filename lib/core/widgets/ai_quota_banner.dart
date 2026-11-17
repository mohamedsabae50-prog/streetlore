import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../services/supabase_service.dart';

class AiQuotaSnapshot {
  const AiQuotaSnapshot({
    required this.remaining,
    required this.limit,
    required this.unlimited,
  });

  final int remaining;
  final int limit;
  final bool unlimited;
}

class AiQuotaBanner extends StatefulWidget {
  const AiQuotaBanner({
    super.key,
    this.fetchQuotaStatus,
    this.onStatusChanged,
    this.onUpgrade,
  });

  final Future<Map<String, dynamic>> Function()? fetchQuotaStatus;
  final ValueChanged<AiQuotaSnapshot>? onStatusChanged;
  final VoidCallback? onUpgrade;

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
    final auth = context.read<AuthProvider>();
    if (auth.isPro || auth.isAdmin) {
      _loading = false;
      return;
    }
    _status = const {'used_today': 0, 'daily_limit': 3, 'remaining': 3};
    _loading = false;
    if (widget.fetchQuotaStatus != null || SupabaseService.instance.isLive) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    _resetTimer?.cancel();
    setState(() {
      _loading = _status == null;
      _error = null;
    });
    try {
      final status =
          await (widget.fetchQuotaStatus?.call() ??
              SupabaseService.instance.fetchAiQuotaStatus());
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      widget.onStatusChanged?.call(_snapshot(status));
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

  void consumeOne() {
    final status = _status;
    if (status == null ||
        status['unlimited'] == true ||
        status['is_unlimited'] == true) {
      return;
    }
    final remaining = (status['remaining'] as num?)?.toInt() ?? 0;
    if (remaining <= 0) return;
    final updated = <String, dynamic>{
      ...status,
      'used_today': ((status['used_today'] as num?)?.toInt() ?? 0) + 1,
      'remaining': remaining - 1,
    };
    setState(() => _status = updated);
    widget.onStatusChanged?.call(_snapshot(updated));
  }

  AiQuotaSnapshot _snapshot(Map<String, dynamic> status) => AiQuotaSnapshot(
    remaining: (status['remaining'] as num?)?.toInt() ?? 0,
    limit: (status['daily_limit'] as num?)?.toInt() ?? 0,
    unlimited: status['unlimited'] == true || status['is_unlimited'] == true,
  );

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.select<AuthProvider, (bool, bool)>(
      (provider) => (provider.isAdmin, provider.isPro),
    );
    final unlimited =
        auth.$1 ||
        auth.$2 ||
        _status?['unlimited'] == true ||
        _status?['is_unlimited'] == true;
    final message = auth.$2 || unlimited
        ? context.tr('ai_quota_pro_unlimited')
        : _loading
        ? context.tr('ai_quota_loading')
        : context.tr('ai_quota_remaining', {
            'remaining': '${_status!['remaining']}',
            'limit': '${_status!['daily_limit']}',
          });
    return Container(
      key: const Key('ai-quota-remaining-banner'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10243A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: Color(0xFF6EE7B7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_loading && _error == null && !unlimited)
                  Text(
                    context.tr('ai_quota_reset_utc'),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                    ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (!unlimited &&
              !_loading &&
              (_status?['remaining'] as num?)?.toInt() == 0 &&
              widget.onUpgrade != null)
            TextButton(
              onPressed: widget.onUpgrade,
              child: Text(context.tr('ai_upgrade_pro')),
            ),
          if (_error != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.tr('ai_quota_retry'),
              onPressed: refresh,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white,
              ),
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
