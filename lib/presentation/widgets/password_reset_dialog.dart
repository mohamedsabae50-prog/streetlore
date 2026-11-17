import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({
    super.key,
    this.initialEmail = '',
    this.recoveryVerified = false,
  });

  final String initialEmail;
  final bool recoveryVerified;

  static Future<void> show(
    BuildContext context, {
    String initialEmail = '',
    bool recoveryVerified = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PasswordResetDialog(
        initialEmail: initialEmail,
        recoveryVerified: recoveryVerified,
      ),
    );
  }

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  late bool _recoveryVerified;
  bool _codeSent = false;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _recoveryVerified = widget.recoveryVerified;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      setState(() {
        _error = context.tr('password_reset_invalid_email');
        _message = null;
      });
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _message = context.tr('password_reset_code_sent');
      });
    });
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = context.tr('password_reset_invalid_code');
        _message = null;
      });
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().verifyPasswordRecoveryOtp(
        email: email,
        token: code,
      );
      if (!mounted) return;
      setState(() {
        _recoveryVerified = true;
        _message = null;
      });
    });
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() {
        _error = context.tr('password_reset_password_short');
        _message = null;
      });
      return;
    }
    if (password != _confirmationController.text) {
      setState(() {
        _error = context.tr('password_reset_password_mismatch');
        _message = null;
      });
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().updatePassword(password);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('password_reset_success'))),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('Password reset failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = context.tr('password_reset_failed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('password_reset_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_recoveryVerified) ...[
              TextField(
                key: const Key('password-reset-email'),
                controller: _emailController,
                enabled: !_codeSent && !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: context.tr('login_email'),
                ),
              ),
              if (!_codeSent) ...[
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('password-reset-send-code'),
                  onPressed: _busy ? null : _sendCode,
                  child: Text(context.tr('password_reset_send_code')),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('password-reset-code'),
                  controller: _codeController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(
                    labelText: context.tr('password_reset_code'),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: const Key('password-reset-verify-code'),
                  onPressed: _busy ? null : _verifyCode,
                  child: Text(context.tr('password_reset_verify_code')),
                ),
              ],
            ],
            if (_recoveryVerified) ...[
              TextField(
                key: const Key('password-reset-new-password'),
                controller: _passwordController,
                enabled: !_busy,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: context.tr('password_reset_new_password'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('password-reset-confirm-password'),
                controller: _confirmationController,
                enabled: !_busy,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr('password_reset_confirm_password'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('password-reset-update-password'),
                onPressed: _busy ? null : _updatePassword,
                child: Text(context.tr('password_reset_update')),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                key: const Key('password-reset-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('password-reset-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
      ],
    );
  }
}
