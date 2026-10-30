import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/place_provider.dart';
import '../widgets/social_user_widgets.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_content_moderation')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.tr('admin_reviews_moderation')),
            Tab(text: context.tr('admin_chat_moderation')),
            Tab(text: context.tr('admin_accounts_avatars')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ReviewModerationTab(),
          _ChatModerationTab(),
          _AccountModerationTab(),
        ],
      ),
    );
  }
}

class _AccountModerationTab extends StatefulWidget {
  const _AccountModerationTab();

  @override
  State<_AccountModerationTab> createState() => _AccountModerationTabState();
}

class _AccountModerationTabState extends State<_AccountModerationTab> {
  List<Map<String, dynamic>> _accounts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Supabase.instance.client.rpc(
        'admin_list_user_accounts',
      );
      if (!mounted) return;
      setState(() {
        _accounts = (result as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Admin moderation: could not load accounts: '
        '$error\n$stackTrace',
      );
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismissReports(Map<String, dynamic> account) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_dismiss_user_reports',
        params: {'target_user_id': account['user_id'].toString()},
      );
      await _load();
    } catch (error, stackTrace) {
      debugPrint(
        'Admin moderation: dismissing account reports failed: '
        '$error\n$stackTrace',
      );
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _removeAvatar(Map<String, dynamic> account) async {
    final confirmed = await _confirmAction(
      context,
      context.tr('admin_clear_avatar_q'),
      context.tr('admin_clear_avatar'),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_remove_user_avatar',
        params: {'target_user_id': account['user_id'].toString()},
      );
      await _load();
    } catch (error, stackTrace) {
      debugPrint(
        'Admin moderation: account avatar removal failed: '
        '$error\n$stackTrace',
      );
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _resetName(Map<String, dynamic> account) async {
    final confirmed = await _confirmAction(
      context,
      context.tr('admin_reset_account_name_q'),
      context.tr('admin_reset_account_name'),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_reset_user_name',
        params: {'target_user_id': account['user_id'].toString()},
      );
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Admin moderation: name reset failed: $error\n$stackTrace');
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _setPro(Map<String, dynamic> account, bool enabled) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_set_user_pro',
        params: {
          'target_user_id': account['user_id'].toString(),
          'pro_enabled': enabled,
        },
      );
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Admin moderation: Pro update failed: $error\n$stackTrace');
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _accounts.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _load);
    }
    if (_accounts.isEmpty) {
      return _EmptyState(label: context.tr('admin_accounts_empty'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final userId = account['user_id']?.toString() ?? '';
          final username = account['username']?.toString().trim() ?? '';
          final flagged = account['is_flagged'] == true;
          final openReports =
              (account['open_report_count'] as num?)?.toInt() ?? 0;
          final reportCount = (account['report_count'] as num?)?.toInt() ?? 0;
          final isPro = account['is_pro'] == true;
          final reason = account['report_reason']?.toString().trim() ?? '';
          final avatarUrl = account['avatar_url']?.toString() ?? '';
          return Card(
            color: flagged || openReports > 0
                ? AppColors.error.withValues(alpha: 0.06)
                : context.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccountReportAvatar(
                        url: avatarUrl,
                        displayName: username,
                        onTap: avatarUrl.trim().isEmpty
                            ? null
                            : () => _showAvatar(context, avatarUrl, username),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.isEmpty ? userId : username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(userId),
                            Wrap(
                              spacing: 6,
                              children: [
                                if (flagged || openReports > 0)
                                  _AccountStatusChip(
                                    label: reason.isEmpty
                                        ? context.tr('content_reported_badge')
                                        : reason,
                                  ),
                                if (reportCount > 0)
                                  _AccountStatusChip(
                                    label: context.tr(
                                      'admin_account_report_count',
                                      {'count': '$reportCount'},
                                    ),
                                  ),
                                if (openReports > 0)
                                  _AccountStatusChip(
                                    label: context.tr(
                                      'admin_account_open_reports',
                                      {'count': '$openReports'},
                                    ),
                                  ),
                                _AccountStatusChip(
                                  label: isPro
                                      ? context.tr('admin_account_pro')
                                      : context.tr('admin_account_free'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (openReports > 0 || flagged)
                        TextButton(
                          onPressed: () => _dismissReports(account),
                          child: Text(context.tr('admin_dismiss_report')),
                        ),
                      TextButton.icon(
                        onPressed: () => _removeAvatar(account),
                        icon: const Icon(Icons.hide_image_outlined, size: 18),
                        label: Text(context.tr('admin_clear_avatar')),
                      ),
                      TextButton.icon(
                        onPressed: () => _resetName(account),
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                        ),
                        label: Text(context.tr('admin_reset_account_name')),
                      ),
                      TextButton.icon(
                        onPressed: () => _setPro(account, !isPro),
                        icon: Icon(
                          isPro
                              ? Icons.workspace_premium_outlined
                              : Icons.workspace_premium_rounded,
                          size: 18,
                        ),
                        label: Text(
                          context.tr(
                            isPro
                                ? 'admin_disable_account_pro'
                                : 'admin_enable_account_pro',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAvatar(
    BuildContext context,
    String url,
    String displayName,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: InteractiveViewer(
        child: url.startsWith('https://') || url.startsWith('http://')
            ? Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(
                    child: ExplorerAvatar(
                      avatarUrl: '',
                      displayName: displayName,
                      radius: 120,
                    ),
                  ),
                ),
              )
            : SizedBox(
                width: 260,
                height: 260,
                child: Center(
                  child: ExplorerAvatar(
                    avatarUrl: url,
                    displayName: displayName,
                    radius: 120,
                  ),
                ),
              ),
      ),
    ),
  );
}

class _ReviewModerationTab extends StatefulWidget {
  const _ReviewModerationTab();

  @override
  State<_ReviewModerationTab> createState() => _ReviewModerationTabState();
}

class _ReviewModerationTabState extends State<_ReviewModerationTab> {
  List<Map<String, dynamic>> _reviews = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('reviews')
          .select()
          .order('is_flagged', ascending: false)
          .order('report_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _reviews = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Admin moderation: could not load reviews: $error\n$stackTrace',
      );
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> review) async {
    final confirmed = await _confirmDelete(
      context,
      context.tr('delete_review_q'),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('reviews')
          .delete()
          .eq('id', review['id'].toString());
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Admin moderation: review delete failed: $error\n$stackTrace');
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _reviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _reviews.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _load);
    }
    if (_reviews.isEmpty) {
      return _EmptyState(label: context.tr('admin_reviews_empty'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
          final flagged =
              review['is_flagged'] == true ||
              (review['report_count'] as num? ?? 0) > 0;
          return Card(
            color: flagged
                ? AppColors.error.withValues(alpha: 0.07)
                : context.cardColor,
            child: ListTile(
              title: Text(
                '${review['user_name'] ?? 'Explorer'} · '
                '${review['rating'] ?? '-'} ★',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_placeName(context, review['place_id'])),
                  Text(review['comment']?.toString() ?? ''),
                  if (flagged)
                    Text(
                      context.tr('content_reported_badge'),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: context.tr('delete'),
                onPressed: () => _delete(review),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatModerationTab extends StatefulWidget {
  const _ChatModerationTab();

  @override
  State<_ChatModerationTab> createState() => _ChatModerationTabState();
}

class _ChatModerationTabState extends State<_ChatModerationTab> {
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('place_chat')
            .select()
            .order('is_flagged', ascending: false)
            .order('report_count', ascending: false)
            .order('created_at', ascending: false)
            .limit(100),
        client
            .from('content_reports')
            .select()
            .eq('status', 'open')
            .order('created_at', ascending: false)
            .limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = (results[0] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _reports = (results[1] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      });
    } catch (error, stackTrace) {
      debugPrint('Admin moderation: could not load chat: $error\n$stackTrace');
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> message) async {
    final confirmed = await _confirmDelete(
      context,
      context.tr('admin_delete_message_q'),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('place_chat')
          .delete()
          .eq('id', message['id'].toString());
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Admin moderation: chat delete failed: $error\n$stackTrace');
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _dismiss(Map<String, dynamic> report) async {
    try {
      await Supabase.instance.client
          .from('content_reports')
          .update({'status': 'dismissed'})
          .eq('id', report['id'].toString());
      await _load();
    } catch (error, stackTrace) {
      debugPrint(
        'Admin moderation: report dismiss failed: $error\n$stackTrace',
      );
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _messages.isEmpty && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty && _reports.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _load);
    }
    if (_messages.isEmpty && _reports.isEmpty) {
      return _EmptyState(label: context.tr('admin_chat_empty'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_reports.isNotEmpty) ...[
            Text(
              context.tr('admin_open_reports'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final report in _reports)
              Card(
                color: AppColors.error.withValues(alpha: 0.07),
                child: ListTile(
                  title: Text(
                    '${report['reason'] ?? ''} · ${report['author_name'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${report['content_preview'] ?? ''}\n'
                    '${_placeName(context, report['place_id'])}',
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: () => _dismiss(report),
                    child: Text(context.tr('admin_dismiss_report')),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            context.tr('admin_recent_messages'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final message in _messages)
            Card(
              color:
                  message['is_flagged'] == true ||
                      ((message['report_count'] as num? ?? 0) > 0)
                  ? AppColors.error.withValues(alpha: 0.07)
                  : context.cardColor,
              child: ListTile(
                title: Text(message['user_name']?.toString() ?? 'Explorer'),
                subtitle: Text(
                  '${message['message'] ?? ''}\n'
                  '${_placeName(context, message['place_id'])}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: context.tr('admin_delete_message'),
                  onPressed: () => _delete(message),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _placeName(BuildContext context, Object? id) {
  final placeId = id?.toString() ?? '';
  final locale = Localizations.localeOf(context).languageCode;
  final PlaceModel? place = context.read<PlaceProvider>().findById(placeId);
  return place?.localizedName(locale) ?? placeId;
}

Future<bool?> _confirmDelete(BuildContext context, String title) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${context.tr('admin_action_failed')}: $error')),
  );
}

Future<bool?> _confirmAction(
  BuildContext context,
  String title,
  String action,
) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: Text(context.tr('cancel')),
      ),
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: Text(action, style: const TextStyle(color: AppColors.error)),
      ),
    ],
  ),
);

class _AccountReportAvatar extends StatelessWidget {
  const _AccountReportAvatar({
    required this.url,
    required this.displayName,
    this.onTap,
  });
  final String url;
  final String displayName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: ExplorerAvatar(
        avatarUrl: url,
        displayName: displayName,
        radius: 26,
      ),
    );
  }
}

class _AccountStatusChip extends StatelessWidget {
  const _AccountStatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.tr('ai_quota_retry')),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
