import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../logic/auth_provider.dart';
import '../../logic/squad_provider.dart';
import '../../l10n/app_strings.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  final _codeController = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createSquad() async {
    setState(() => _working = true);
    try {
      final squad = await context.read<SquadProvider>().createSquad();
      if (mounted) _showMessage('Squad created. Share code ${squad.joinCode}.');
    } catch (error) {
      if (mounted) _showMessage('Could not create squad: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _joinSquad() async {
    setState(() => _working = true);
    try {
      final squad = await context
          .read<SquadProvider>()
          .joinSquad(_codeController.text);
      if (mounted) _showMessage('Joined squad ${squad.joinCode}.');
    } catch (error) {
      if (mounted) _showMessage('Could not join squad: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _leaveSquad() async {
    setState(() => _working = true);
    try {
      await context.read<SquadProvider>().leaveSquad();
      if (mounted) _showMessage('You left the squad.');
    } catch (error) {
      if (mounted) _showMessage('Could not leave squad: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.watch<AuthProvider>().userId.isNotEmpty;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(context.tr('squad_title')),
        backgroundColor: context.bgColor,
        foregroundColor: context.textPri,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _working
                ? null
                : () => context.read<SquadProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh squad',
          ),
        ],
      ),
      body: Consumer<SquadProvider>(
        builder: (context, squadProvider, _) {
          final session = squadProvider.session;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Explore together',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Create a squad or join one with a short code. '
                      'Check in together to earn the rare Squad Explorer badge.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (squadProvider.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    squadProvider.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (!isSignedIn)
                _messageCard(
                  context,
                  context.tr('squad_sign_in'),
                  Icons.lock_outline_rounded,
                )
              else if (session != null)
                _activeSquad(context, session)
              else ...[
                FilledButton.icon(
                  onPressed: _working || squadProvider.isLoading
                      ? null
                      : _createSquad,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(context.tr('squad_create')),
                ),
                const SizedBox(height: 20),
                _messageCard(
                  context,
                  'Already have a code?',
                  Icons.key_rounded,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  enabled: !_working,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) {
                    if (!_working) _joinSquad();
                  },
                  decoration: InputDecoration(
                    labelText: context.tr('squad_code_label'),
                    counterText: '',
                    filled: true,
                    fillColor: context.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _working || squadProvider.isLoading
                      ? null
                      : _joinSquad,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPri,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(context.tr('squad_join')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _activeSquad(BuildContext context, SquadSession squad) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('squad_active_title'),
                  style: TextStyle(
                    color: context.textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                context.tr('squad_members', {'n': '${squad.memberCount}'}),
                style: TextStyle(color: context.textSec, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                Text(
                  'JOIN CODE',
                  style: TextStyle(
                    color: context.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  squad.joinCode,
                  style: TextStyle(
                    color: context.textPri,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: squad.joinCode),
                    );
                    if (mounted) _showMessage('Squad code copied.');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(context.tr('squad_copy_code')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Your squad stays active for 24 hours. A check-in while you are '
            'a member earns the Squad Explorer badge once.',
            style: TextStyle(color: context.textSec, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _working ? null : _leaveSquad,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('squad_leave')),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(BuildContext context, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.textSec),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: context.textSec)),
          ),
        ],
      ),
    );
  }
}
