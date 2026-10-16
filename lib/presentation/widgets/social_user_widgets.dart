import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_defaults.dart';
import '../../data/models/social_user.dart';
import '../../l10n/app_strings.dart';

class SocialUserAvatar extends StatelessWidget {
  const SocialUserAvatar({required this.user, this.radius = 24, super.key});

  final SocialUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initialsSource = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.username.trim();
    final initials = initialsSource.isEmpty
        ? '?'
        : initialsSource.characters.first.toUpperCase();
    final imageUrl = user.avatarUrl.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: ClipOval(
        child: imageUrl.startsWith('https://') || imageUrl.startsWith('http://')
            ? Image.network(
                imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                headers: streetloreImageHeaders,
                errorBuilder: (_, _, _) => _initials(initials, radius),
              )
            : _initials(initials, radius),
      ),
    );
  }

  Widget _initials(String initials, double radius) => Center(
    child: Text(
      initials,
      style: TextStyle(
        color: AppColors.primary,
        fontSize: radius * 0.8,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
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

class SocialFollowCounts extends StatelessWidget {
  const SocialFollowCounts({
    required this.followers,
    required this.following,
    super.key,
  });

  final int followers;
  final int following;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      _count(context, followers, context.tr('profile_followers')),
      _count(context, following, context.tr('profile_following')),
    ],
  );

  Widget _count(BuildContext context, int count, String label) => Text.rich(
    TextSpan(
      style: TextStyle(color: context.textSec, fontSize: 13),
      children: [
        TextSpan(
          text: '$count ',
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        TextSpan(text: label),
      ],
    ),
  );
}
