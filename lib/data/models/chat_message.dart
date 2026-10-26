class ChatMessage {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String text;
  final DateTime sentAt;
  final String? userAvatarColor;
  final String? userEmail;
  final String? avatarUrl;
  final bool isFlagged;
  final int reportCount;

  const ChatMessage({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.sentAt,
    this.userAvatarColor,
    this.userEmail,
    this.avatarUrl,
    this.isFlagged = false,
    this.reportCount = 0,
  });

  /// Parses current and legacy `public.place_chat` rows. The migration
  /// preserves text IDs and timestamps while normalizing the message body.
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    placeId: json['place_id'] as String,
    userId: (json['user_id'] as String?) ?? '',
    userName: (json['user_name'] as String?) ?? 'Explorer',
    text: (json['message'] ?? json['text']) as String,
    sentAt: (json['created_at'] ?? json['sent_at']) == null
        ? DateTime.now()
        : DateTime.parse((json['created_at'] ?? json['sent_at']) as String),
    userAvatarColor: json['user_avatar_color'] as String?,
    userEmail: json['user_email'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    isFlagged: json['is_flagged'] as bool? ?? false,
    reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
  );

  /// The insert payload for `public.place_chat`; generated fields are omitted.
  /// `user_id` must equal `auth.uid()` for the insert RLS policy.
  Map<String, dynamic> toJson() => {
    'place_id': placeId,
    'user_id': userId,
    'user_name': userName,
    'message': text,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };

  ChatMessage copyWith({String? text}) => ChatMessage(
    id: id,
    placeId: placeId,
    userId: userId,
    userName: userName,
    text: text ?? this.text,
    sentAt: sentAt,
    userAvatarColor: userAvatarColor,
    userEmail: userEmail,
    avatarUrl: avatarUrl,
    isFlagged: isFlagged,
    reportCount: reportCount,
  );
}
