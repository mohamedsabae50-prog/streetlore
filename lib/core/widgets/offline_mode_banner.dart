import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../logic/connectivity_provider.dart';

class OfflineModeBanner extends StatelessWidget {
  const OfflineModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOffline = context.select<ConnectivityProvider, bool?>(
      (connectivity) => connectivity.hasInternet,
    );
    if (isOffline != false) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF17342F),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                context.tr('offline_mode_notice'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
