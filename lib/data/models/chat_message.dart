
class ChatMessage {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String text;
  final DateTime sentAt;
  final String? userAvatarColor; 

  const ChatMessage({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.sentAt,
    this.userAvatarColor,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        placeId: json['place_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        text: json['text'] as String,
        sentAt: DateTime.parse(json['sent_at'] as String),
        userAvatarColor: json['user_avatar_color'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'place_id': placeId,
        'user_id': userId,
        'user_name': userName,
        'text': text,
        'sent_at': sentAt.toIso8601String(),
        'user_avatar_color': userAvatarColor,
      };

  ChatMessage copyWith({String? text}) => ChatMessage(
        id: id,
        placeId: placeId,
        userId: userId,
        userName: userName,
        text: text ?? this.text,
        sentAt: sentAt,
        userAvatarColor: userAvatarColor,
      );
}
