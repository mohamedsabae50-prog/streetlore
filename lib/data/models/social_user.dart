class SocialUser {
  final String userId;
  final String username;
  final String displayName;
  final bool isFollowing;

  const SocialUser({
    required this.userId,
    required this.username,
    this.displayName = '',
    this.isFollowing = false,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    userId: json['user_id']?.toString() ?? '',
    username: json['username']?.toString() ?? 'explorer',
    displayName: json['display_name']?.toString() ?? '',
    isFollowing: json['is_following'] == true,
  );
}
