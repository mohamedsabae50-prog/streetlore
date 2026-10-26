import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/place_provider.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ReviewModerationTab(), _ChatModerationTab()],
      ),
    );
  }
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
