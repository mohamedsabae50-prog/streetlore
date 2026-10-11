import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: Text(context.tr('privacy_policy_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            context.tr('privacy_policy_intro'),
            style: TextStyle(
              color: context.textSec,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          _PolicySection(
            icon: Icons.person_outline_rounded,
            title: context.tr('privacy_data_title'),
            body: context.tr('privacy_data_body'),
          ),
          _PolicySection(
            icon: Icons.location_on_outlined,
            title: context.tr('privacy_location_title'),
            body: context.tr('privacy_location_body'),
          ),
          _PolicySection(
            icon: Icons.travel_explore_rounded,
            title: context.tr('privacy_geofence_title'),
            body: '${context.tr('privacy_background_location')}\n\n'
                '${context.tr('privacy_geofence_body')}',
          ),
          _PolicySection(
            icon: Icons.notifications_none_rounded,
            title: context.tr('privacy_notifications_title'),
            body: context.tr('privacy_notifications_body'),
          ),
          _PolicySection(
            icon: Icons.tune_rounded,
            title: context.tr('privacy_controls_title'),
            body: context.tr('privacy_controls_body'),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hintColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.textPri,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: context.textSec,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
