class SocialUser {
  final String userId;
  final String username;

  const SocialUser({required this.userId, required this.username});

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    userId: json['user_id'] as String,
    username: json['username'] as String,
  );
}
