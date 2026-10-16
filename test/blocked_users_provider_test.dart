import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/blocked_users_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('blocked users remain hidden after provider reload', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = BlockedUsersProvider();
    await provider.setUserId('local-user');
    await provider.blockUser('blocked-user');
    expect(provider.isBlocked('blocked-user'), isTrue);

    final reloaded = BlockedUsersProvider();
    await reloaded.setUserId('local-user');
    expect(reloaded.isBlocked('blocked-user'), isTrue);
  });
}
