import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_tour_guide_service.dart';
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
    final limit = auth.isPro || auth.isAdmin
        ? kProDailyAiLimit
        : kFreeDailyAiLimit;
    _status = AiQuotaStatus(
      dailyLimit: limit,
      usedToday: 0,
      nextResetAt: _nextUtcReset(),
    ).toMap();
    _loading = false;
    refresh();
  }

  DateTime _nextUtcReset() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day + 1);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    _resetTimer?.cancel();
    setState(() {
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final shouldFetchServer =
          widget.fetchQuotaStatus != null || SupabaseService.instance.isLive;
      final status = await AITourGuideService.resolveQuotaStatus(
        isPro: auth.isPro || auth.isAdmin,
        userId: auth.currentUserId,
        fetchServerStatus: shouldFetchServer
            ? widget.fetchQuotaStatus ??
                  SupabaseService.instance.fetchAiQuotaStatus
            : null,
      );
      if (!mounted) return;
      final statusMap = status.toMap();
      setState(() {
        _status = statusMap;
        _loading = false;
      });
      widget.onStatusChanged?.call(_snapshot(statusMap));
      final untilReset = status.nextResetAt.difference(DateTime.now().toUtc());
      final delay = untilReset <= Duration.zero
          ? const Duration(seconds: 1)
          : untilReset;
      _resetTimer = Timer(delay, refresh);
    } catch (error, stackTrace) {
      debugPrint('AiQuotaBanner.refresh failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'ai_quota_unavailable';
        _loading = false;
      });
      _resetTimer = Timer(const Duration(minutes: 1), refresh);
    }
  }

  Future<bool> consumeOne() async {
    final status = _status;
    if (status == null) return false;
    final auth = context.read<AuthProvider>();
    final updatedStatus = await AITourGuideService.consumeLocalQuota(
      isPro: auth.isPro || auth.isAdmin,
      userId: auth.currentUserId,
      observedServerUsage: (status['used_today'] as num?)?.toInt() ?? 0,
    );
    if (!mounted) return false;
    final updated = updatedStatus.toMap();
    setState(() => _status = updated);
    widget.onStatusChanged?.call(_snapshot(updated));
    return true;
  }

  AiQuotaSnapshot _snapshot(Map<String, dynamic> status) => AiQuotaSnapshot(
    remaining: (status['remaining'] as num?)?.toInt() ?? 0,
    limit: (status['daily_limit'] as num?)?.toInt() ?? 0,
    unlimited: false,
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
    final isPro = auth.$1 || auth.$2;
    final limit = isPro
        ? kProDailyAiLimit
        : (_status?['daily_limit'] as num?)?.toInt() ?? kFreeDailyAiLimit;
    final remaining = (_status?['remaining'] as num?)?.toInt() ?? limit;
    final message = isPro
        ? context.tr('ai_quota_pro_remaining', {
            'remaining': '$remaining',
            'limit': '$limit',
          })
        : context.tr('ai_quota_remaining', {
            'remaining': '$remaining',
            'limit': '$limit',
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
                if (!_loading && _error == null)
                  Text(
                    context.tr('ai_quota_reset_utc'),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                    ),
                  ),
                if (_error != null)
                  Text(
                    context.tr(_error!),
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
          if (!isPro &&
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
