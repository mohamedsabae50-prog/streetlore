import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/achievement_catalog.dart';

void main() {
  test('includes the requested visit, category, and social badges', () {
    const expected = <String, (int, int, AchievementCategory)>{
      'first_steps': (1, 50, AchievementCategory.exploration),
      'street_explorer': (5, 100, AchievementCategory.exploration),
      'lore_master': (15, 250, AchievementCategory.exploration),
      'alexandria_legend': (30, 500, AchievementCategory.exploration),
      'time_traveler': (5, 150, AchievementCategory.historical),
      'culture_vulture': (5, 150, AchievementCategory.culture),
      'alex_foodie': (5, 120, AchievementCategory.food),
      'nature_lover': (3, 100, AchievementCategory.nature),
      'social_explorer': (3, 100, AchievementCategory.social),
      'cafe_hopper': (4, 50, AchievementCategory.cafes),
      'shopaholic': (4, 35, AchievementCategory.shopping),
      'tour_finisher': (1, 50, AchievementCategory.exploration),
      'grand_tour_master': (3, 150, AchievementCategory.exploration),
      'community_spark': (5, 40, AchievementCategory.social),
      'lens_of_alexandria': (3, 40, AchievementCategory.social),
      'bookmark_collector': (5, 75, AchievementCategory.exploration),
    };

    expect(AchievementCatalog.all.length, greaterThanOrEqualTo(18));
    for (final entry in expected.entries) {
      final definition = AchievementCatalog.byId(entry.key);
      expect(definition, isNotNull, reason: entry.key);
      expect(definition!.target, entry.value.$1, reason: entry.key);
      expect(definition.points, entry.value.$2, reason: entry.key);
      expect(definition.category, entry.value.$3, reason: entry.key);
    }
  });
}
