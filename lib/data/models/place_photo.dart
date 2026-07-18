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

  PlacePhoto copyWith({
    int? likes,
    Set<String>? likedBy,
  }) =>
      PlacePhoto(
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

  factory PlacePhoto.fromMap(Map<String, dynamic> map) => PlacePhoto(
        id: map['id'] as String,
        placeId: map['placeId'] as String,
        userId: map['userId'] as String,
        userName: map['userName'] as String,
        imageUrl: map['imageUrl'] as String,
        caption: (map['caption'] as String?) ?? '',
        likes: (map['likes'] as int?) ?? 0,
        date: DateTime.parse(map['date'] as String),
        likedBy: ((map['likedBy'] as List<dynamic>?) ?? const [])
            .cast<String>()
            .toSet(),
      );
}
