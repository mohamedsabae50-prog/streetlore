import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/global_progress_reset_service.dart';
import 'package:streetlore/core/services/offline_storage_service.dart';
import 'package:streetlore/data/models/gamification_stats.dart';
import 'package:streetlore/logic/achievement_provider.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/gamification_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/streak_provider.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Box<dynamic> syncQueue;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
    hiveDirectory = await Directory.systemTemp.createTemp(
      'global-progress-reset-',
    );
    Hive.init(hiveDirectory.path);
    syncQueue = await Hive.openBox<dynamic>(OfflineStorageService.syncQueueBox);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await syncQueue.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('the reset epoch clears cached progress for every local user', () async {
    final oldStats = GamificationStats(
      userId: 'guest',
      userName: 'Explorer',
      totalPoints: 740,
      placesVisited: 12,
      reviewsPosted: 3,
      photosUploaded: 2,
      chatMessagesSent: 7,
      badges: const [
        Badge(
          id: 'first_steps',
          name: 'First Steps',
          description: 'First check-in',
          iconName: 'first-steps',
          tier: 'bronze',
          pointsAwarded: 50,
        ),
      ],
      currentStreak: 5,
      longestStreak: 8,
      totalVisitDays: 11,
      lastVisitDate: DateTime.utc(2026, 11, 15),
    );
    SharedPreferences.setMockInitialValues({
      'global_progress_reset_epoch': 'older_epoch',
      'gamification_stats_v2_guest': jsonEncode(oldStats.toJson()),
      'gamification_activity_guest': ['{"type":"check_in"}'],
      'gamification_post_reset_action_guest': true,
      'gamification_stats_v2_other-user': jsonEncode(
        oldStats.copyWith().toJson(),
      ),
      'streak_v3_guest': jsonEncode({
        'currentStreak': 5,
        'longestStreak': 8,
        'totalVisitDays': 11,
        'lastVisitDate': '2026-11-15T00:00:00.000Z',
        'visitedDates': ['2026-11-11', '2026-11-12', '2026-11-13'],
      }),
      'achievements_v2_guest': 'first_steps::1::1::2026-11-15T00:00:00.000Z',
      'visited_place_ids_guest': ['old-place-1', 'old-place-2'],
      'automatically_visited_tour_ids': ['old-tour'],
    });
    await syncQueue.put(
      'old-checkin',
      jsonEncode({
        'type': 'checkin',
        'user_id': 'guest',
        'place_id': 'old-place-1',
        'checked_in_at': '2026-11-15T00:00:00.000Z',
      }),
    );
    await syncQueue.put('unrelated-queue-item', '{"type":"other"}');

    final auth = AuthProvider();
    final gamification = GamificationProvider()..syncWithAuth(auth);
    final places = PlaceProvider(watchRemoteUpdates: false);
    final tours = TourProvider();
    final streak = StreakProvider();
    await streak.setUserId('guest');
    final trips = TripProvider();

    await gamification.bootstrapForUser('guest');
    final achievements = AchievementProvider(
      auth: auth,
      gam: gamification,
      places: places,
      streak: streak,
      tours: tours,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('global_progress_reset_epoch'),
      kGlobalProgressResetEpoch,
    );
    final savedStats = GamificationStats.fromJson(
      jsonDecode(prefs.getString('gamification_stats_v2_guest')!)
          as Map<String, dynamic>,
    );
    expect(savedStats.totalPoints, 0);
    expect(savedStats.placesVisited, 0);
    expect(savedStats.badges, isEmpty);
    expect(prefs.getString('gamification_stats_v2_other-user'), isNull);
    expect(prefs.getStringList('gamification_activity_guest'), isNull);
    expect(prefs.getString('achievements_v2_guest'), isNull);
    expect(prefs.getString('streak_v3_guest'), isNull);
    expect(prefs.getStringList('visited_place_ids_guest'), isNull);
    expect(prefs.getStringList('automatically_visited_tour_ids'), isNull);
    expect(prefs.getBool('gamification_post_reset_action_guest'), isNull);
    expect(gamification.stats.totalPoints, 0);
    expect(gamification.stats.placesVisited, 0);
    expect(gamification.stats.badges, isEmpty);
    expect(streak.currentStreak, 0);
    expect(streak.longestStreak, 0);
    expect(streak.lastVisitDate, isNull);
    expect(streak.hasStreakToday, isFalse);
    expect(achievements.totalUnlocked, 0);
    expect(trips.visitedPlaceIds, isEmpty);
    expect(syncQueue.get('old-checkin'), isNull);
    expect(syncQueue.get('unrelated-queue-item'), isNotNull);

    await prefs.setString('gamification_stats_v2_guest', 'fresh');
    await GlobalProgressResetService.ensureReset();
    expect(prefs.getString('gamification_stats_v2_guest'), 'fresh');

    achievements.dispose();
    places.dispose();
    tours.dispose();
    streak.dispose();
    trips.dispose();
    gamification.dispose();
    auth.dispose();
  });

  test('a check-in after the reset starts progress from zero', () async {
    SharedPreferences.setMockInitialValues({
      'global_progress_reset_epoch': kGlobalProgressResetEpoch,
    });
    final gamification = GamificationProvider();
    final streak = StreakProvider();
    await streak.setUserId('guest');

    expect(gamification.stats.totalPoints, 0);
    expect(gamification.stats.placesVisited, 0);
    await gamification.applyAction('check_in', placeId: 'new-place');
    await streak.registerVisit();

    expect(
      gamification.stats.totalPoints,
      GamificationStats.pointsFor('check_in'),
    );
    expect(gamification.stats.placesVisited, 1);
    expect(streak.currentStreak, 1);
    expect(streak.longestStreak, 1);

    gamification.dispose();
    streak.dispose();
  });

  test(
    'empty remote progress does not restore stale local XP or visits',
    () async {
      final staleStats = GamificationStats(
        userId: 'me',
        userName: 'Explorer',
        totalPoints: 900,
        placesVisited: 15,
        badges: const [
          Badge(
            id: 'old_badge',
            name: 'Old badge',
            description: 'Old',
            iconName: 'old',
            tier: 'bronze',
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'global_progress_reset_epoch': kGlobalProgressResetEpoch,
        'gamification_stats_v2_me': jsonEncode(staleStats.toJson()),
      });
      final gamification = GamificationProvider();

      await gamification.bootstrapForUser('me');

      expect(gamification.stats.totalPoints, 0);
      expect(gamification.stats.placesVisited, 0);
      expect(gamification.stats.badges, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final saved = GamificationStats.fromJson(
        jsonDecode(prefs.getString('gamification_stats_v2_me')!)
            as Map<String, dynamic>,
      );
      expect(saved.totalPoints, 0);
      expect(saved.placesVisited, 0);
      expect(saved.badges, isEmpty);

      gamification.dispose();
    },
  );
}
