import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';

class ReportContentSheet extends StatefulWidget {
  final String targetId;
  final String targetType;

  const ReportContentSheet({
    super.key,
    required this.targetId,
    required this.targetType,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required String targetType,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        ReportContentSheet(targetId: targetId, targetType: targetType),
  );

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  static const _reasonKeys = [
    'report_reason_inappropriate',
    'report_reason_spam',
    'report_reason_harassment',
    'report_reason_false_info',
    'report_reason_other',
  ];
  String _selectedReasonKey = 'report_reason_inappropriate';
  bool _submitting = false;
  String? _error;

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
        reason: switch (_selectedReasonKey) {
          'report_reason_inappropriate' => 'Inappropriate content',
          'report_reason_spam' => 'Spam',
          'report_reason_harassment' => 'Harassment',
          'report_reason_false_info' => 'False information',
          _ => 'Other',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('report_submitted'))),
      );
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
            Text(
              context.tr('report_title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(context.tr('report_reason_prompt')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reasonKey in _reasonKeys)
                  ChoiceChip(
                    label: Text(context.tr(reasonKey)),
                    selected: _selectedReasonKey == reasonKey,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(
                            () => _selectedReasonKey = reasonKey,
                          ),
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
