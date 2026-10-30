import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'social_user_widgets.dart';

class ReportContentSheet extends StatefulWidget {
  final String targetId;
  final String targetType;
  final String? targetContext;
  final String? authorName;
  final String? targetAvatarUrl;

  const ReportContentSheet({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetContext,
    this.authorName,
    this.targetAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required String targetType,
    String? targetContext,
    String? authorName,
    String? targetAvatarUrl,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportContentSheet(
      targetId: targetId,
      targetType: targetType,
      targetContext: targetContext,
      authorName: authorName,
      targetAvatarUrl: targetAvatarUrl,
    ),
  );

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  static const _generalReasonKeys = [
    'report_reason_inappropriate',
    'report_reason_spam',
    'report_reason_harassment',
    'report_reason_false_info',
    'report_reason_other',
  ];
  static const _contentReasonKeys = [
    'report_reason_offensive',
    'report_reason_inappropriate',
    'report_reason_spam',
  ];
  static const _userReasonKeys = [
    'report_user_reason_avatar',
    'report_user_reason_offensive_profile',
    'report_user_reason_fake_account',
  ];
  late String _selectedReasonKey;
  late String _targetAvatarUrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedReasonKey = widget.targetType == 'user'
        ? _userReasonKeys.first
        : 'report_reason_inappropriate';
    _targetAvatarUrl = widget.targetAvatarUrl?.trim() ?? '';
    if (widget.targetType == 'user' &&
        _targetAvatarUrl.isEmpty &&
        widget.targetId.trim().isNotEmpty) {
      _loadTargetAvatar();
    }
  }

  Future<void> _loadTargetAvatar() async {
    try {
      final target = await SupabaseService.instance.getSocialUser(
        widget.targetId,
      );
      if (!mounted || target == null || target.avatarUrl.trim().isEmpty) return;
      setState(() => _targetAvatarUrl = target.avatarUrl.trim());
    } catch (error, stackTrace) {
      debugPrint(
        'ReportContentSheet: target avatar could not be loaded: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _submit() async {
    final reporterId = context.read<AuthProvider>().userId;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SupabaseService.instance.submitReport(
        reporterId: reporterId,
        targetId: widget.targetId,
        targetType: widget.targetType,
        targetContext: widget.targetContext,
        authorName: widget.authorName,
        userId: widget.targetType == 'user' ? widget.targetId : null,
        name: widget.targetType == 'user' ? widget.authorName : null,
        avatarUrl: widget.targetType == 'user' ? _targetAvatarUrl : null,
        reason: switch (_selectedReasonKey) {
          'report_user_reason_avatar' => 'Inappropriate profile picture',
          'report_user_reason_offensive_profile' =>
            'Offensive username or profile',
          'report_user_reason_fake_account' => 'Spam or fake account',
          'report_reason_inappropriate' => 'Inappropriate content',
          'report_reason_spam' => 'Spam',
          'report_reason_offensive' => 'Offensive language',
          'report_reason_harassment' => 'Harassment',
          'report_reason_false_info' => 'False information',
          _ => 'Other',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('report_submitted'))));
    } catch (error, stackTrace) {
      debugPrint('ReportContentSheet: submission failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = context.tr('report_failed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.targetType == 'user')
              Row(
                children: [
                  _TargetAvatar(
                    url: _targetAvatarUrl,
                    displayName: widget.authorName ?? '',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('report_account'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (widget.authorName?.trim().isNotEmpty == true)
                          Text(widget.authorName!.trim()),
                      ],
                    ),
                  ),
                ],
              )
            else
              Text(
                context.tr('report_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: 8),
            Text(context.tr('report_reason_prompt')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reasonKey in widget.targetType == 'user'
                    ? _userReasonKeys
                    : widget.targetType == 'chat' ||
                          widget.targetType == 'review'
                    ? _contentReasonKeys
                    : _generalReasonKeys)
                  ChoiceChip(
                    label: Text(context.tr(reasonKey)),
                    selected: _selectedReasonKey == reasonKey,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _selectedReasonKey = reasonKey),
                  ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('report_submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetAvatar extends StatelessWidget {
  const _TargetAvatar({required this.url, required this.displayName});
  final String url;
  final String displayName;

  @override
  Widget build(BuildContext context) => ExplorerAvatar(
    avatarUrl: url,
    displayName: displayName,
    radius: 22,
  );
}
