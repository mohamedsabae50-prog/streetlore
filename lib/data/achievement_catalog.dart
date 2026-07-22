import 'package:flutter/material.dart';

enum AchievementTier { bronze, silver, gold, platinum }

enum AchievementCategory {
  exploration,
  culture,
  food,
  social,
  streak,
  hidden,
  special,
}

class AchievementDefinition {
  final String id;
  final IconData icon;
  final Color color;
  final AchievementTier tier;
  final AchievementCategory category;
  final int target;
  final int points;
  final String nameKey;
  final String descKey;

  const AchievementDefinition({
    required this.id,
    required this.icon,
    required this.color,
    required this.tier,
    required this.category,
    required this.target,
    required this.points,
    required this.nameKey,
    required this.descKey,
  });
}

class AchievementCatalog {
  AchievementCatalog._();

  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: 'first_steps',
      icon: Icons.flag_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
      target: 1,
      points: 10,
      nameKey: 'ach_first_steps_name',
      descKey: 'ach_first_steps_desc',
    ),
    AchievementDefinition(
      id: 'explorer_5',
      icon: Icons.explore_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
      target: 5,
      points: 25,
      nameKey: 'ach_explorer_5_name',
      descKey: 'ach_explorer_5_desc',
    ),
    AchievementDefinition(
      id: 'explorer_10',
      icon: Icons.travel_explore_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 10,
      points: 50,
      nameKey: 'ach_explorer_10_name',
      descKey: 'ach_explorer_10_desc',
    ),
    AchievementDefinition(
      id: 'explorer_25',
      icon: Icons.public_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.exploration,
      target: 25,
      points: 100,
      nameKey: 'ach_explorer_25_name',
      descKey: 'ach_explorer_25_desc',
    ),
    AchievementDefinition(
      id: 'lorekeeper',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFE5E4E2),
      tier: AchievementTier.platinum,
      category: AchievementCategory.exploration,
      target: 42,
      points: 500,
      nameKey: 'ach_lorekeeper_name',
      descKey: 'ach_lorekeeper_desc',
    ),
    AchievementDefinition(
      id: 'culture_buff',
      icon: Icons.museum_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.culture,
      target: 5,
      points: 40,
      nameKey: 'ach_culture_buff_name',
      descKey: 'ach_culture_buff_desc',
    ),
    AchievementDefinition(
      id: 'history_nerd',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.culture,
      target: 10,
      points: 80,
      nameKey: 'ach_history_nerd_name',
      descKey: 'ach_history_nerd_desc',
    ),
    AchievementDefinition(
      id: 'foodie',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.food,
      target: 3,
      points: 30,
      nameKey: 'ach_foodie_name',
      descKey: 'ach_foodie_desc',
    ),
    AchievementDefinition(
      id: 'gourmet',
      icon: Icons.local_dining_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.food,
      target: 8,
      points: 75,
      nameKey: 'ach_gourmet_name',
      descKey: 'ach_gourmet_desc',
    ),
    AchievementDefinition(
      id: 'shopaholic',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 3,
      points: 35,
      nameKey: 'ach_shopaholic_name',
      descKey: 'ach_shopaholic_desc',
    ),
    AchievementDefinition(
      id: 'spiritual_seeker',
      icon: Icons.mosque_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.culture,
      target: 2,
      points: 35,
      nameKey: 'ach_spiritual_seeker_name',
      descKey: 'ach_spiritual_seeker_desc',
    ),
    AchievementDefinition(
      id: 'pilgrim',
      icon: Icons.church_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.culture,
      target: 2,
      points: 50,
      nameKey: 'ach_pilgrim_name',
      descKey: 'ach_pilgrim_desc',
    ),
    AchievementDefinition(
      id: 'streak_3',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.streak,
      target: 3,
      points: 20,
      nameKey: 'ach_streak_3_name',
      descKey: 'ach_streak_3_desc',
    ),
    AchievementDefinition(
      id: 'streak_7',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.streak,
      target: 7,
      points: 50,
      nameKey: 'ach_streak_7_name',
      descKey: 'ach_streak_7_desc',
    ),
    AchievementDefinition(
      id: 'streak_30',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.streak,
      target: 30,
      points: 200,
      nameKey: 'ach_streak_30_name',
      descKey: 'ach_streak_30_desc',
    ),
    AchievementDefinition(
      id: 'streak_100',
      icon: Icons.flash_on_rounded,
      color: Color(0xFFE5E4E2),
      tier: AchievementTier.platinum,
      category: AchievementCategory.streak,
      target: 100,
      points: 1000,
      nameKey: 'ach_streak_100_name',
      descKey: 'ach_streak_100_desc',
    ),
    AchievementDefinition(
      id: 'hidden_gem_hunter',
      icon: Icons.diamond_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.hidden,
      target: 3,
      points: 75,
      nameKey: 'ach_hidden_gem_hunter_name',
      descKey: 'ach_hidden_gem_hunter_desc',
    ),
    AchievementDefinition(
      id: 'reviewer',
      icon: Icons.rate_review_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.social,
      target: 3,
      points: 25,
      nameKey: 'ach_reviewer_name',
      descKey: 'ach_reviewer_desc',
    ),
    AchievementDefinition(
      id: 'critic',
      icon: Icons.edit_note_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.social,
      target: 10,
      points: 60,
      nameKey: 'ach_critic_name',
      descKey: 'ach_critic_desc',
    ),
    AchievementDefinition(
      id: 'photographer',
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.social,
      target: 5,
      points: 30,
      nameKey: 'ach_photographer_name',
      descKey: 'ach_photographer_desc',
    ),
    AchievementDefinition(
      id: 'influencer',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.social,
      target: 20,
      points: 100,
      nameKey: 'ach_influencer_name',
      descKey: 'ach_influencer_desc',
    ),
    AchievementDefinition(
      id: 'early_bird',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.special,
      target: 5,
      points: 40,
      nameKey: 'ach_early_bird_name',
      descKey: 'ach_early_bird_desc',
    ),
    AchievementDefinition(
      id: 'night_owl',
      icon: Icons.nights_stay_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.special,
      target: 5,
      points: 40,
      nameKey: 'ach_night_owl_name',
      descKey: 'ach_night_owl_desc',
    ),
    AchievementDefinition(
      id: 'completionist',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFE5E4E2),
      tier: AchievementTier.platinum,
      category: AchievementCategory.special,
      target: 20,
      points: 500,
      nameKey: 'ach_completionist_name',
      descKey: 'ach_completionist_desc',
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Color tierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  static String tierName(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
    }
  }
}
