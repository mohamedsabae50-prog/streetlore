
class Badge {
  final String id;
  final String name;
  final String description;
  final String iconName; 
  final String tier; 
  final DateTime? earnedAt; 
  final int pointsAwarded;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.tier,
    this.earnedAt,
    this.pointsAwarded = 0,
  });
}

class GamificationStats {
  final String userId;
  final String userName;
  final String? avatarColorHex;
  final int totalPoints;
  final int placesVisited;
  final int reviewsPosted;
  final int routesCreated;
  final int photosUploaded;
  final List<Badge> badges;
  final String level; 

  const GamificationStats({
    required this.userId,
    required this.userName,
    this.avatarColorHex,
    this.totalPoints = 0,
    this.placesVisited = 0,
    this.reviewsPosted = 0,
    this.routesCreated = 0,
    this.photosUploaded = 0,
    this.badges = const [],
    this.level = 'Explorer',
  });

  GamificationStats copyWith({
    int? totalPoints,
    int? placesVisited,
    int? reviewsPosted,
    int? routesCreated,
    int? photosUploaded,
    List<Badge>? badges,
    String? level,
  }) =>
      GamificationStats(
        userId: userId,
        userName: userName,
        avatarColorHex: avatarColorHex,
        totalPoints: totalPoints ?? this.totalPoints,
        placesVisited: placesVisited ?? this.placesVisited,
        reviewsPosted: reviewsPosted ?? this.reviewsPosted,
        routesCreated: routesCreated ?? this.routesCreated,
        photosUploaded: photosUploaded ?? this.photosUploaded,
        badges: badges ?? this.badges,
        level: level ?? this.level,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'avatar_color_hex': avatarColorHex,
        'total_points': totalPoints,
        'places_visited': placesVisited,
        'reviews_posted': reviewsPosted,
        'routes_created': routesCreated,
        'photos_uploaded': photosUploaded,
        'badges': badges
            .map((b) => {
                  'id': b.id,
                  'name': b.name,
                  'description': b.description,
                  'icon_name': b.iconName,
                  'tier': b.tier,
                  'earned_at': b.earnedAt?.toIso8601String(),
                  'points_awarded': b.pointsAwarded,
                })
            .toList(),
        'level': level,
      };

  factory GamificationStats.fromJson(Map<String, dynamic> json) =>
      GamificationStats(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        avatarColorHex: json['avatar_color_hex'] as String?,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        placesVisited: (json['places_visited'] as num?)?.toInt() ?? 0,
        reviewsPosted: (json['reviews_posted'] as num?)?.toInt() ?? 0,
        routesCreated: (json['routes_created'] as num?)?.toInt() ?? 0,
        photosUploaded: (json['photos_uploaded'] as num?)?.toInt() ?? 0,
        badges: ((json['badges'] as List<dynamic>?) ?? const [])
            .map((b) => Badge(
                  id: b['id'] as String,
                  name: b['name'] as String,
                  description: b['description'] as String,
                  iconName: b['icon_name'] as String,
                  tier: b['tier'] as String,
                  earnedAt: b['earned_at'] == null
                      ? null
                      : DateTime.parse(b['earned_at'] as String),
                  pointsAwarded: (b['points_awarded'] as num?)?.toInt() ?? 0,
                ))
            .toList(),
        level: json['level'] as String? ?? 'Explorer',
      );

  
  static String levelForPoints(int points) {
    if (points >= 5000) return 'Lorekeeper';
    if (points >= 2000) return 'Cartographer';
    if (points >= 500) return 'Wanderer';
    return 'Explorer';
  }

  
  static int pointsFor(String action) {
    switch (action) {
      case 'check_in':
        return 50;
      case 'review':
        return 20;
      case 'photo':
        return 30;
      case 'route_created':
        return 100;
      case 'route_liked':
        return 5;
      case 'chat_message':
        return 2;
      default:
        return 0;
    }
  }
}
