import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import 'main_navigation.dart';

class ChooseUsernameScreen extends StatefulWidget {
  final String initialUsername;

  const ChooseUsernameScreen({super.key, this.initialUsername = ''});

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  late final TextEditingController _usernameController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    final error = await context.read<AuthProvider>().claimUsername(
      _usernameController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _isSaving = false);
      final key = switch (error) {
        'username_taken' => 'username_taken',
        'username_invalid' => 'username_invalid',
        _ => 'username_save_failed',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(key)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,19}$').hasMatch(username)) {
      return context.tr('username_requirements');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.tr('username_title')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.alternate_email_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('username_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('username_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSec),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 20,
                      decoration: InputDecoration(
                        labelText: context.tr('username_label'),
                        prefixText: '@',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: _validateUsername,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(context.tr('username_continue')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
