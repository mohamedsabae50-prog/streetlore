import 'package:flutter/material.dart';

enum AchievementTier { bronze, silver, gold, platinum }

enum AchievementCategory {
  exploration,
  historical,
  culture,
  food,
  cafes,
  shopping,
  nature,
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
      id: 'first_step',
      icon: Icons.flag_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
      target: 1,
      points: 50,
      nameKey: 'ach_first_steps_name',
      descKey: 'ach_first_steps_desc',
    ),
    AchievementDefinition(
      id: 'street_explorer',
      icon: Icons.explore_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
      target: 5,
      points: 100,
      nameKey: 'ach_street_explorer_name',
      descKey: 'ach_street_explorer_desc',
    ),
    AchievementDefinition(
      id: 'lore_master',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 15,
      points: 250,
      nameKey: 'ach_lore_master_name',
      descKey: 'ach_lore_master_desc',
    ),
    AchievementDefinition(
      id: 'alexandria_legend',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.exploration,
      target: 30,
      points: 500,
      nameKey: 'ach_alexandria_legend_name',
      descKey: 'ach_alexandria_legend_desc',
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
      id: 'time_traveler',
      icon: Icons.history_edu_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.historical,
      target: 5,
      points: 150,
      nameKey: 'ach_time_traveler_name',
      descKey: 'ach_time_traveler_desc',
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
      id: 'alex_foodie',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.food,
      target: 5,
      points: 120,
      nameKey: 'ach_alex_foodie_name',
      descKey: 'ach_alex_foodie_desc',
    ),
    AchievementDefinition(
      id: 'nature_lover',
      icon: Icons.park_rounded,
      color: Color(0xFF10B981),
      tier: AchievementTier.bronze,
      category: AchievementCategory.nature,
      target: 3,
      points: 100,
      nameKey: 'ach_nature_lover_name',
      descKey: 'ach_nature_lover_desc',
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
      category: AchievementCategory.shopping,
      target: 4,
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
      target: 1,
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
      target: 5,
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
    AchievementDefinition(
      id: 'squad_explorer',
      icon: Icons.groups_rounded,
      color: Color(0xFFFFD700),
      tier: AchievementTier.gold,
      category: AchievementCategory.special,
      target: 1,
      points: 125,
      nameKey: 'ach_squad_explorer_name',
      descKey: 'ach_squad_explorer_desc',
    ),
    AchievementDefinition(
      id: 'social_explorer',
      icon: Icons.diversity_3_rounded,
      color: Color(0xFF7C3AED),
      tier: AchievementTier.silver,
      category: AchievementCategory.social,
      target: 3,
      points: 100,
      nameKey: 'ach_social_explorer_name',
      descKey: 'ach_social_explorer_desc',
    ),
    AchievementDefinition(
      id: 'cafe_hopper',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.cafes,
      target: 4,
      points: 50,
      nameKey: 'badge_cafe_hopper_name',
      descKey: 'badge_cafe_hopper_desc',
    ),
    AchievementDefinition(
      id: 'tour_finisher',
      icon: Icons.flag_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.exploration,
      target: 1,
      points: 50,
      nameKey: 'badge_tour_finisher_name',
      descKey: 'badge_tour_finisher_desc',
    ),
    AchievementDefinition(
      id: 'grand_tour_master',
      icon: Icons.route_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 3,
      points: 150,
      nameKey: 'badge_grand_tour_master_name',
      descKey: 'badge_grand_tour_master_desc',
    ),
    AchievementDefinition(
      id: 'community_spark',
      icon: Icons.forum_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.social,
      target: 5,
      points: 40,
      nameKey: 'badge_community_spark_name',
      descKey: 'badge_community_spark_desc',
    ),
    AchievementDefinition(
      id: 'lens_of_alexandria',
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFCD7F32),
      tier: AchievementTier.bronze,
      category: AchievementCategory.social,
      target: 3,
      points: 40,
      nameKey: 'badge_lens_of_alexandria_name',
      descKey: 'badge_lens_of_alexandria_desc',
    ),
    AchievementDefinition(
      id: 'bookmark_collector',
      icon: Icons.bookmark_rounded,
      color: Color(0xFFC0C0C0),
      tier: AchievementTier.silver,
      category: AchievementCategory.exploration,
      target: 5,
      points: 75,
      nameKey: 'badge_bookmark_collector_name',
      descKey: 'badge_bookmark_collector_desc',
    ),
  ];

  static String canonicalId(String id) => switch (id) {
    'first_steps' || 'b_checkin_first' => 'first_step',
    'culture_vulture' => 'culture_buff',
    _ => id,
  };

  static AchievementDefinition? byId(String id) {
    final canonical = canonicalId(id);
    for (final a in all) {
      if (a.id == canonical) return a;
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
