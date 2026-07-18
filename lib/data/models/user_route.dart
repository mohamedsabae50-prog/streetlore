import 'place_model.dart';

class UserRoute {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final List<String> placeIds; 
  final int likes;
  final int saves;
  final DateTime createdAt;
  final String? coverImageUrl;
  final List<String> tags; 

  const UserRoute({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.placeIds,
    this.likes = 0,
    this.saves = 0,
    required this.createdAt,
    this.coverImageUrl,
    this.tags = const [],
  });

  factory UserRoute.fromJson(Map<String, dynamic> json) => UserRoute(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        authorId: json['author_id'] as String,
        authorName: json['author_name'] as String,
        placeIds: (json['place_ids'] as List<dynamic>).cast<String>(),
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        saves: (json['saves'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        coverImageUrl: json['cover_image_url'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'author_id': authorId,
        'author_name': authorName,
        'place_ids': placeIds,
        'likes': likes,
        'saves': saves,
        'created_at': createdAt.toIso8601String(),
        'cover_image_url': coverImageUrl,
        'tags': tags,
      };

  UserRoute copyWith({int? likes, int? saves}) => UserRoute(
        id: id,
        title: title,
        description: description,
        authorId: authorId,
        authorName: authorName,
        placeIds: placeIds,
        likes: likes ?? this.likes,
        saves: saves ?? this.saves,
        createdAt: createdAt,
        coverImageUrl: coverImageUrl,
        tags: tags,
      );
}

class RouteStop {
  final PlaceModel place;
  final String? note;

  const RouteStop({required this.place, this.note});
}
