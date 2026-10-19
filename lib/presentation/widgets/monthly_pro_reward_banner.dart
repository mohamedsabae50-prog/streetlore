import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../screens/suggest_place_screen.dart';

class MonthlyProRewardBanner extends StatefulWidget {
  const MonthlyProRewardBanner({super.key});

  @override
  State<MonthlyProRewardBanner> createState() => _MonthlyProRewardBannerState();
}

class _MonthlyProRewardBannerState extends State<MonthlyProRewardBanner> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthEnd = DateTime(_now.year, _now.month + 1);
    final remaining = monthEnd.difference(_now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('pro_monthly_reward_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                child: Text(
                  context.tr('pro_monthly_reward_countdown', {
                    'days': '$days',
                    'hours': '$hours',
                  }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SuggestPlaceScreen(),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(context.tr('pro_monthly_reward_cta')),
          ),
        ],
      ),
    );
  }
}
