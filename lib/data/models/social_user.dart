class SocialUser {
  final String userId;
  final String username;
  final String displayName;
  final bool isFollowing;
  final String avatarUrl;
  final int friendsCount;
  final int followersCount;
  final int followingCount;
  final List<Map<String, dynamic>> badges;

  const SocialUser({
    required this.userId,
    required this.username,
    this.displayName = '',
    this.isFollowing = false,
    this.avatarUrl = '',
    this.friendsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.badges = const [],
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    final rawBadges = json['badges'];
    return SocialUser(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString().trim() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      isFollowing: json['is_following'] == true,
      avatarUrl: json['avatar_url']?.toString() ?? '',
      friendsCount:
          (json['friends_count'] as num?)?.toInt() ??
          (json['followers_count'] as num?)?.toInt() ??
          0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      badges: rawBadges is List
          ? rawBadges
                .whereType<Map>()
                .map((badge) => Map<String, dynamic>.from(badge))
                .toList(growable: false)
          : const [],
    );
  }
}
