import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/social_user.dart';
import 'package:streetlore/logic/squad_provider.dart';

void main() {
  test('SocialUser parses public profile counts, avatar, and badges', () {
    final user = SocialUser.fromJson({
      'user_id': 'user-1',
      'username': 'explorer',
      'display_name': 'City Explorer',
      'is_following': true,
      'avatar_url': 'https://example.com/avatar.png',
      'followers_count': 12,
      'following_count': 7,
      'badges': [
        {'id': 'first_visit', 'name': 'First Visit'},
      ],
    });

    expect(user.userId, 'user-1');
    expect(user.displayName, 'City Explorer');
    expect(user.isFollowing, isTrue);
    expect(user.avatarUrl, 'https://example.com/avatar.png');
    expect(user.friendsCount, 12);
    expect(user.followersCount, 12);
    expect(user.followingCount, 7);
    expect(user.badges.single['id'], 'first_visit');
  });

  test('SocialUser prefers the mutual-friend count when available', () {
    final user = SocialUser.fromJson({
      'user_id': 'user-2',
      'username': 'friend',
      'friends_count': 4,
      'followers_count': 12,
    });

    expect(user.friendsCount, 4);
  });

  test('SquadSession parses roster members and leader status', () {
    final squad = SquadSession.fromJson({
      'id': 'squad-1',
      'join_code': '123456',
      'created_by': 'user-1',
      'member_count': 2,
      'expires_at': '2026-10-17T12:00:00Z',
      'members': [
        {
          'user_id': 'user-1',
          'username': 'leader',
          'display_name': 'Squad Leader',
          'is_leader': true,
        },
        {
          'user_id': 'user-2',
          'username': 'member',
          'display_name': 'Explorer',
          'is_leader': false,
        },
      ],
    });

    expect(squad.members, hasLength(2));
    expect(squad.members.first.user.displayName, 'Squad Leader');
    expect(squad.members.first.isLeader, isTrue);
    expect(squad.members.last.isLeader, isFalse);
  });
}
