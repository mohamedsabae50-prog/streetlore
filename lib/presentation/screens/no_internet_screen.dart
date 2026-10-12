import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../logic/connectivity_provider.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  context.tr('no_internet_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('no_internet_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : const Color(0xFF64748B),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: connectivity.isChecking
                      ? null
                      : connectivity.refresh,
                  icon: connectivity.isChecking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('no_internet_retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
