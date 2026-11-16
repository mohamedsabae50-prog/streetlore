import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/gamification_stats.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/achievement_provider.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/gamification_badge_progress.dart';
import 'package:streetlore/logic/gamification_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/streak_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  test('achievement counts use check-ins across governorates', () async {
    final places = [
      const PlaceModel(
        id: 'alexandria-place',
        nameEn: 'Alexandria Place',
        descriptionEn: '',
        imageUrl: '',
        rating: 0,
        category: 'Historical',
        lat: 31.2,
        lng: 29.9,
        governorate: 'alexandria',
      ),
      const PlaceModel(
        id: 'cairo-food',
        nameEn: 'Cairo Food Place',
        descriptionEn: '',
        imageUrl: '',
        rating: 0,
        category: 'Food',
        lat: 30.0,
        lng: 31.2,
        governorate: 'cairo',
      ),
      const PlaceModel(
        id: 'atm_non_visitable',
        nameEn: 'ATM',
        descriptionEn: '',
        imageUrl: '',
        rating: 0,
        category: 'ATM',
        lat: 31.2,
        lng: 29.9,
      ),
    ];
    final auth = AuthProvider();
    final gam = GamificationProvider();
    final placeProvider = PlaceProvider(
      watchRemoteUpdates: false,
      initialPlaces: places,
    );
    final tours = TourProvider();
    final streak = StreakProvider();
    tours.syncVisitedPlaces({
      'alexandria-place',
      'cairo-food',
      'atm_non_visitable',
      'removed-place',
    }, places);
    final achievements = AchievementProvider(
      auth: auth,
      gam: gam,
      places: placeProvider,
      streak: streak,
      tours: tours,
    );
    addTearDown(() {
      achievements.dispose();
      placeProvider.dispose();
      tours.dispose();
      streak.dispose();
      gam.dispose();
      auth.dispose();
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(achievements.progressFor('foodie').current, 1);
    expect(achievements.progressFor('explorer_5').current, 2);
    expect(gam.stats.placesVisited, 2);

    expect(GamificationStats.badgeCatalog, hasLength(27));
    final badgeProgress = GamificationBadgeProgress.calculate(
      stats: gam.stats,
      allPlaces: placeProvider.allPlaces,
      checkedInPlaceIds: tours.checkedInPlaceIds,
      toursCompleted: tours.visitedToursCount,
      achievements: achievements,
    );
    expect(badgeProgress['visit_5'], 2);
  });
}
