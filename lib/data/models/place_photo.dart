class PlacePhoto {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String imageUrl;
  final String caption;
  final int likes;
  final DateTime date;
  final Set<String> likedBy;

  const PlacePhoto({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.imageUrl,
    this.caption = '',
    this.likes = 0,
    required this.date,
    Set<String>? likedBy,
  }) : likedBy = likedBy ?? const {};

  bool isLikedBy(String userId) => likedBy.contains(userId);

  PlacePhoto copyWith({int? likes, Set<String>? likedBy}) => PlacePhoto(
    id: id,
    placeId: placeId,
    userId: userId,
    userName: userName,
    imageUrl: imageUrl,
    caption: caption,
    likes: likes ?? this.likes,
    date: date,
    likedBy: likedBy ?? this.likedBy,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'placeId': placeId,
    'userId': userId,
    'userName': userName,
    'imageUrl': imageUrl,
    'caption': caption,
    'likes': likes,
    'date': date.toIso8601String(),
    'likedBy': likedBy.toList(),
  };

  /// v1.0.72 — snake_case payload for Supabase. Required because the
  /// `place_photos.user_id` column is snake_case (not camelCase like the
  /// mobile local cache key).
  Map<String, dynamic> toSupabaseInsert() => {
    'id': id,
    'place_id': placeId,
    'user_id': userId,
    'user_name': userName,
    'image_url': imageUrl,
    'caption': caption,
    'likes': likes,
    'created_at': date.toIso8601String(),
  };

  factory PlacePhoto.fromMap(Map<String, dynamic> map) => PlacePhoto(
    id: map['id'] as String,
    placeId: (map['placeId'] ?? map['place_id']) as String,
    // v1.0.72 — accept both camelCase (local cache) and snake_case
    // (Supabase) for userId/user_id so the same model works for both.
    userId: ((map['userId'] ?? map['user_id']) as String?) ?? '',
    userName: (map['userName'] ?? map['user_name']) as String,
    imageUrl: (map['imageUrl'] ?? map['image_url']) as String,
    caption: (map['caption'] as String?) ?? '',
    likes: (map['likes'] as int?) ?? 0,
    date: DateTime.parse(
      (map['date'] ?? map['created_at']) as String,
    ),
    likedBy: ((map['likedBy'] as List<dynamic>?) ?? const [])
        .cast<String>()
        .toSet(),
  );
}
