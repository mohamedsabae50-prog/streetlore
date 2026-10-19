import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_defaults.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';

class ExplorerAvatar extends StatelessWidget {
  const ExplorerAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.radius,
    this.fallbackColor = AppColors.primary,
    super.key,
  });

  final String avatarUrl;
  final String displayName;
  final double radius;
  final Color fallbackColor;

  static const presets = <String, ({IconData icon, Color color})>{
    'builtin:explorer': (icon: Icons.explore_rounded, color: Color(0xFF0F766E)),
    'builtin:historian': (
      icon: Icons.account_balance_rounded,
      color: Color(0xFF92400E),
    ),
    'builtin:scholar': (
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF4338CA),
    ),
    'builtin:sailor': (icon: Icons.sailing_rounded, color: Color(0xFF0369A1)),
  };

  static const presetUrls = <String>[
    'builtin:explorer',
    'builtin:historian',
    'builtin:scholar',
    'builtin:sailor',
  ];

  @override
  Widget build(BuildContext context) {
    final initialsSource = displayName.trim();
    final initials = initialsSource.isEmpty
        ? '?'
        : initialsSource.characters.first.toUpperCase();
    final preset = presets[avatarUrl.split('?').first];
    return CircleAvatar(
      radius: radius,
      backgroundColor: preset?.color ?? fallbackColor.withValues(alpha: 0.12),
      child: ClipOval(
        child: preset != null
            ? Icon(preset.icon, color: Colors.white, size: radius)
            : avatarUrl.startsWith('https://') ||
                  avatarUrl.startsWith('http://')
            ? Image.network(
                avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                headers: streetloreImageHeaders,
                errorBuilder: (_, _, _) => _initials(initials),
              )
            : _initials(initials),
      ),
    );
  }

  Widget _initials(String initials) => Center(
    child: Text(
      initials,
      style: TextStyle(
        color: fallbackColor,
        fontSize: radius * 0.8,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class SocialUserAvatar extends StatelessWidget {
  const SocialUserAvatar({required this.user, this.radius = 24, super.key});

  final SocialUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExplorerAvatar(
      avatarUrl: user.avatarUrl,
      displayName: user.displayName.trim().isNotEmpty
          ? user.displayName
          : user.username,
      radius: radius,
    );
  }
}

class SocialBadges extends StatelessWidget {
  const SocialBadges({required this.badges, this.compact = false, super.key});

  final List<Map<String, dynamic>> badges;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Text(
        context.tr('profile_no_public_badges'),
        style: TextStyle(color: context.textSec, fontSize: 12),
      );
    }

    final shown = compact ? badges.take(3) : badges;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final badge in shown)
          Chip(
            avatar: Icon(
              _badgeIcon(badge['icon_name']?.toString()),
              color: AppColors.ratingGold,
              size: 17,
            ),
            label: Text(
              badge['name']?.toString().trim().isNotEmpty == true
                  ? badge['name'].toString()
                  : context.tr('badge_earned_fallback'),
            ),
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        if (compact && badges.length > 3)
          Chip(label: Text('+${badges.length - 3}')),
      ],
    );
  }

  IconData _badgeIcon(String? iconName) => switch (iconName) {
    'place' || 'location_on' => Icons.place_rounded,
    'explore' || 'exploration' => Icons.explore_rounded,
    'groups' || 'group' => Icons.groups_rounded,
    'photo' || 'camera_alt' => Icons.camera_alt_rounded,
    'route' || 'map' => Icons.map_rounded,
    _ => Icons.workspace_premium_rounded,
  };
}

class SocialFriendCount extends StatelessWidget {
  const SocialFriendCount({required this.friends, super.key});

  final int friends;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: TextStyle(color: context.textSec, fontSize: 13),
      children: [
        TextSpan(
          text: '$friends ',
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        TextSpan(text: context.tr('profile_friends')),
      ],
    ),
  );
}
