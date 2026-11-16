import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models/egypt_governorate.dart';
import '../data/models/gamification_stats.dart';
import '../data/models/place_model.dart';
import 'achievement_provider.dart';

class GamificationBadgeProgress {
  const GamificationBadgeProgress._();

  static Map<String, int> calculate({
    required GamificationStats stats,
    required Iterable<PlaceModel> allPlaces,
    required Set<String> checkedInPlaceIds,
    required int toursCompleted,
    required AchievementProvider achievements,
  }) {
    final visitedPlaces = allPlaces
        .where(
          (place) => place.isVisitable && checkedInPlaceIds.contains(place.id),
        )
        .toList(growable: false);
    final alexandriaVisits = _countInGovernorates(visitedPlaces, {
      'alexandria',
    });
    final cairoGizaVisits = _countInGovernorates(visitedPlaces, {
      'cairo',
      'giza',
    });
    final upperEgyptVisits = _countInGovernorates(visitedPlaces, {
      'luxor',
      'aswan',
    });
    final regionCount =
        (alexandriaVisits > 0 ? 1 : 0) +
        (cairoGizaVisits > 0 ? 1 : 0) +
        (upperEgyptVisits > 0 ? 1 : 0);

    return Map.unmodifiable({
      for (final badge in GamificationStats.badgeCatalog)
        badge.id: math.max(switch (badge.metric) {
          GamificationBadgeMetric.placesVisited => visitedPlaces.length,
          GamificationBadgeMetric.alexandriaVisits => alexandriaVisits,
          GamificationBadgeMetric.cairoGizaVisits => cairoGizaVisits,
          GamificationBadgeMetric.upperEgyptVisits => upperEgyptVisits,
          GamificationBadgeMetric.allRegions => regionCount,
          GamificationBadgeMetric.toursCompleted => toursCompleted,
          GamificationBadgeMetric.aiHistorian => stats.chatMessagesSent,
          GamificationBadgeMetric.streakDays => stats.currentStreak,
        }, _achievementProgressFor(badge.id, achievements)).toInt(),
    });
  }

  static bool isUnlocked(
    GamificationBadgeDefinition badge,
    int current,
    GamificationStats stats,
  ) {
    return current >= badge.target ||
        stats.badges.any((earned) => earned.id == badge.id);
  }

  static IconData iconFor(String iconName) => switch (iconName) {
    'place' => Icons.place_rounded,
    'explore' => Icons.explore_rounded,
    'workspace_premium' => Icons.workspace_premium_rounded,
    'location_city' => Icons.location_city_rounded,
    'public' => Icons.public_rounded,
    'check_circle' => Icons.check_circle_rounded,
    'route' => Icons.route_rounded,
    'psychology' => Icons.psychology_rounded,
    'local_fire_department' => Icons.local_fire_department_rounded,
    _ => Icons.emoji_events_rounded,
  };

  static int _countInGovernorates(
    List<PlaceModel> places,
    Set<String> governorateIds,
  ) {
    return places
        .where(
          (place) => governorateIds.contains(
            EgyptGovernorate.normalizeId(place.governorate),
          ),
        )
        .length;
  }

  static int _achievementProgressFor(
    String badgeId,
    AchievementProvider achievements,
  ) {
    final achievementId = switch (badgeId) {
      'visit_1' || 'first_checkin' => 'first_step',
      'visit_5' => 'explorer_5',
      'visit_10' => 'explorer_10',
      'visit_25' => 'explorer_25',
      'tour_finisher_1' => 'tour_finisher',
      'tour_finisher_5' || 'tour_finisher_10' => 'grand_tour_master',
      'ai_historian' => 'community_spark',
      'streak_3_days' => 'streak_3',
      'streak_7_days' => 'streak_7',
      'streak_14_days' || 'streak_30_days' => 'streak_30',
      _ => null,
    };
    return achievementId == null
        ? 0
        : achievements.progressFor(achievementId).current;
  }
}
