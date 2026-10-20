import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/activity_feed_filter.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/blocked_users_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/activity_feed_screen.dart';
import 'package:streetlore/presentation/widgets/monthly_pro_reward_banner.dart';

class _SignedOutAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => false;

  @override
  bool get isGuest => false;

  @override
  String get userId => '';

  @override
  String get username => '';

  @override
  String get userName => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'activity feed filtering excludes own events and badge notifications',
    () {
      final filtered = filterOtherUsersActivity(
        [
          {'actor_id': 'current-user', 'event_type': 'badge'},
          {'actor_id': 'other-user', 'event_type': 'checkin'},
          {'user_id': 'current-user', 'event_type': 'badge'},
          {
            'actor_id': 'me',
            'actor_username': 'hero killer',
            'body': 'hero killer unlocked a new badge.',
            'event_type': 'badge',
          },
          {'actor_id': 'other-user', 'type': 'friend_request'},
        ],
        'current-user',
        currentUsername: 'hero killer',
      );

      expect(filtered, hasLength(2));
      expect(filtered.any((row) => row['event_type'] == 'checkin'), isTrue);
      expect(filtered.any((row) => row['type'] == 'friend_request'), isTrue);
    },
  );

  testWidgets('Activity screen does not render the leaderboard promo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
            value: _SignedOutAuthProvider(),
          ),
          ChangeNotifierProvider<BlockedUsersProvider>(
            create: (_) => BlockedUsersProvider(),
          ),
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
        ],
        child: const MaterialApp(home: ActivityFeedScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(MonthlyProRewardBanner), findsNothing);
    expect(find.textContaining('Finish #1 Top Visitor'), findsNothing);
  });
}
