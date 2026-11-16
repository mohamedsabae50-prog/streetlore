import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/gamification_stats.dart';

void main() {
  test('defines 25 progressive bilingual XP levels through 15000 XP', () {
    final levels = GamificationStats.levels;

    expect(levels, hasLength(25));
    expect(levels.first.minimumPoints, 0);
    expect(levels.first.titleEn, 'Novice Traveler');
    expect(levels.first.titleAr, 'رحالة مبتدئ');
    expect(levels.last.minimumPoints, 15000);
    expect(levels.last.titleEn, 'Immortal Pharaoh of EgyptLore');
    expect(levels.last.titleAr, 'فرعون إيجيبت لور الخالد');
    expect(
      levels.map((level) => level.minimumPoints).toSet().length,
      levels.length,
    );
    for (var index = 1; index < levels.length; index++) {
      expect(
        levels[index].minimumPoints,
        greaterThan(levels[index - 1].minimumPoints),
      );
    }

    expect(GamificationStats.levelForPoints(0), 'Novice Traveler');
    expect(GamificationStats.levelForPoints(14999), levels[23].titleEn);
    expect(GamificationStats.levelForPoints(15000), levels.last.titleEn);
    expect(
      GamificationStats.levelDetailsForPoints(15000).titleForLocale('ar'),
      'فرعون إيجيبت لور الخالد',
    );
  });

  test(
    'includes the requested bilingual visit, regional, tour and streak badges',
    () {
      final catalog = GamificationStats.badgeCatalog;
      final ids = catalog.map((badge) => badge.id).toSet();

      expect(catalog.length, greaterThanOrEqualTo(24));
      expect(ids.length, catalog.length);
      expect(
        catalog
            .where(
              (badge) => badge.metric == GamificationBadgeMetric.placesVisited,
            )
            .map((badge) => badge.target)
            .toSet(),
        containsAll([1, 5, 10, 25, 50, 75, 100, 150, 200, 250, 300]),
      );
      expect(
        ids,
        containsAll([
          'alexandria_explorer',
          'pearl_mediterranean',
          'cairo_giza_explorer',
          'guardian_pyramids',
          'upper_egypt_pioneer',
          'lord_thebes_nubia',
          'grand_master_egyptlore',
          'first_checkin',
          'tour_finisher_1',
          'tour_finisher_5',
          'tour_finisher_10',
          'ai_historian',
          'streak_3_days',
          'streak_7_days',
          'streak_14_days',
          'streak_30_days',
        ]),
      );
      for (final badge in catalog) {
        expect(badge.nameEn, isNotEmpty, reason: badge.id);
        expect(badge.nameAr, isNotEmpty, reason: badge.id);
        expect(badge.descriptionEn, isNotEmpty, reason: badge.id);
        expect(badge.descriptionAr, isNotEmpty, reason: badge.id);
      }
    },
  );
}
