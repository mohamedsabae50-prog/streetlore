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

enum GamificationBadgeMetric {
  placesVisited,
  alexandriaVisits,
  cairoGizaVisits,
  upperEgyptVisits,
  allRegions,
  toursCompleted,
  aiHistorian,
  streakDays,
}

class GamificationBadgeDefinition {
  final String id;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final String iconName;
  final String tier;
  final GamificationBadgeMetric metric;
  final int target;

  const GamificationBadgeDefinition({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.iconName,
    required this.tier,
    required this.metric,
    required this.target,
  });
}

class GamificationLevel {
  final int number;
  final int minimumPoints;
  final String titleEn;
  final String titleAr;

  const GamificationLevel({
    required this.number,
    required this.minimumPoints,
    required this.titleEn,
    required this.titleAr,
  });

  String titleForLocale(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;
}

class GamificationStats {
  final String userId;
  final String userName;
  final String? avatarColorHex;
  final String avatarUrl;
  final int totalPoints;
  final int placesVisited;
  final int reviewsPosted;
  final int photosUploaded;
  final int chatMessagesSent;
  final List<Badge> badges;
  final String level;

  // v1.0.56: streak snapshot reflected into the stats object so
  // the UI never reads a value out of sync with the StreakProvider.
  final int currentStreak;
  final int longestStreak;
  final int totalVisitDays;
  final DateTime? lastVisitDate;

  const GamificationStats({
    required this.userId,
    required this.userName,
    this.avatarColorHex,
    this.avatarUrl = '',
    this.totalPoints = 0,
    this.placesVisited = 0,
    this.reviewsPosted = 0,
    this.photosUploaded = 0,
    this.chatMessagesSent = 0,
    this.badges = const [],
    this.level = 'Explorer',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalVisitDays = 0,
    this.lastVisitDate,
  });

  GamificationStats copyWith({
    int? totalPoints,
    int? placesVisited,
    int? reviewsPosted,
    int? photosUploaded,
    int? chatMessagesSent,
    List<Badge>? badges,
    String? level,
    int? currentStreak,
    int? longestStreak,
    int? totalVisitDays,
    DateTime? lastVisitDate,
    bool clearLastVisitDate = false,
  }) => GamificationStats(
    userId: userId,
    userName: userName,
    avatarColorHex: avatarColorHex,
    avatarUrl: avatarUrl,
    totalPoints: totalPoints ?? this.totalPoints,
    placesVisited: placesVisited ?? this.placesVisited,
    reviewsPosted: reviewsPosted ?? this.reviewsPosted,
    photosUploaded: photosUploaded ?? this.photosUploaded,
    chatMessagesSent: chatMessagesSent ?? this.chatMessagesSent,
    badges: badges ?? this.badges,
    level: level ?? this.level,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    totalVisitDays: totalVisitDays ?? this.totalVisitDays,
    lastVisitDate: clearLastVisitDate
        ? null
        : lastVisitDate ?? this.lastVisitDate,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'user_name': userName,
    'avatar_color_hex': avatarColorHex,
    'total_points': totalPoints,
    'places_visited': placesVisited,
    'reviews_posted': reviewsPosted,
    'photos_uploaded': photosUploaded,
    'chat_messages_sent': chatMessagesSent,
    'badges': badges
        .map(
          (b) => {
            'id': b.id,
            'name': b.name,
            'description': b.description,
            'icon_name': b.iconName,
            'tier': b.tier,
            'earned_at': b.earnedAt?.toIso8601String(),
            'points_awarded': b.pointsAwarded,
          },
        )
        .toList(),
    'level': level,
    'current_streak': currentStreak,
    'longest_streak': longestStreak,
    'total_visit_days': totalVisitDays,
    'last_visit_date': lastVisitDate?.toIso8601String(),
  };

  factory GamificationStats.fromJson(Map<String, dynamic> json) =>
      GamificationStats(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        avatarColorHex: json['avatar_color_hex'] as String?,
        avatarUrl: json['avatar_url'] as String? ?? '',
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        placesVisited: (json['places_visited'] as num?)?.toInt() ?? 0,
        reviewsPosted: (json['reviews_posted'] as num?)?.toInt() ?? 0,
        photosUploaded: (json['photos_uploaded'] as num?)?.toInt() ?? 0,
        chatMessagesSent: (json['chat_messages_sent'] as num?)?.toInt() ?? 0,
        badges: ((json['badges'] as List<dynamic>?) ?? const [])
            .map(
              (b) => Badge(
                id: b['id'] as String,
                name: b['name'] as String,
                description: b['description'] as String,
                iconName: b['icon_name'] as String,
                tier: b['tier'] as String,
                earnedAt: b['earned_at'] == null
                    ? null
                    : DateTime.parse(b['earned_at'] as String),
                pointsAwarded: (b['points_awarded'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
        level: json['level'] as String? ?? 'Explorer',
        currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
        totalVisitDays: (json['total_visit_days'] as num?)?.toInt() ?? 0,
        lastVisitDate: json['last_visit_date'] == null
            ? null
            : DateTime.parse(json['last_visit_date'] as String),
      );

  static String levelForPoints(int points) {
    return levelDetailsForPoints(points).titleEn;
  }

  static GamificationLevel levelDetailsForPoints(int points) {
    for (final level in levels.reversed) {
      if (points >= level.minimumPoints) return level;
    }
    return levels.first;
  }

  static int pointsFor(String action) {
    switch (action) {
      case 'check_in':
        return 50;
      case 'review':
        return 20;
      case 'photo':
        return 30;
      case 'chat_message':
        return 2;
      default:
        return 0;
    }
  }

  static const List<GamificationLevel> levels = [
    GamificationLevel(
      number: 1,
      minimumPoints: 0,
      titleEn: 'Novice Traveler',
      titleAr: 'رحالة مبتدئ',
    ),
    GamificationLevel(
      number: 2,
      minimumPoints: 100,
      titleEn: 'Curious Wanderer',
      titleAr: 'متجول فضولي',
    ),
    GamificationLevel(
      number: 3,
      minimumPoints: 200,
      titleEn: 'City Scout',
      titleAr: 'كشاف المدينة',
    ),
    GamificationLevel(
      number: 4,
      minimumPoints: 350,
      titleEn: 'Pathfinder',
      titleAr: 'مستكشف الدروب',
    ),
    GamificationLevel(
      number: 5,
      minimumPoints: 500,
      titleEn: 'Local Explorer',
      titleAr: 'مستكشف محلي',
    ),
    GamificationLevel(
      number: 6,
      minimumPoints: 700,
      titleEn: 'Heritage Seeker',
      titleAr: 'باحث عن التراث',
    ),
    GamificationLevel(
      number: 7,
      minimumPoints: 900,
      titleEn: 'Street Historian',
      titleAr: 'مؤرخ الشوارع',
    ),
    GamificationLevel(
      number: 8,
      minimumPoints: 1200,
      titleEn: 'Cultural Voyager',
      titleAr: 'رحالة ثقافي',
    ),
    GamificationLevel(
      number: 9,
      minimumPoints: 1500,
      titleEn: 'Nile Navigator',
      titleAr: 'ملاح النيل',
    ),
    GamificationLevel(
      number: 10,
      minimumPoints: 1900,
      titleEn: 'Keeper of Stories',
      titleAr: 'حارس الحكايات',
    ),
    GamificationLevel(
      number: 11,
      minimumPoints: 2300,
      titleEn: 'Antiquity Tracker',
      titleAr: 'متعقب الآثار',
    ),
    GamificationLevel(
      number: 12,
      minimumPoints: 2800,
      titleEn: 'Desert Wayfinder',
      titleAr: 'دليل الصحراء',
    ),
    GamificationLevel(
      number: 13,
      minimumPoints: 3400,
      titleEn: 'Temple Scholar',
      titleAr: 'باحث المعابد',
    ),
    GamificationLevel(
      number: 14,
      minimumPoints: 4000,
      titleEn: 'Master Cartographer',
      titleAr: 'رسام خرائط خبير',
    ),
    GamificationLevel(
      number: 15,
      minimumPoints: 4700,
      titleEn: 'Guardian of Heritage',
      titleAr: 'حارس التراث',
    ),
    GamificationLevel(
      number: 16,
      minimumPoints: 5500,
      titleEn: 'Scribe of the Nile',
      titleAr: 'كاتب النيل',
    ),
    GamificationLevel(
      number: 17,
      minimumPoints: 6400,
      titleEn: 'Chronicle Keeper',
      titleAr: 'حافظ السجلات',
    ),
    GamificationLevel(
      number: 18,
      minimumPoints: 7400,
      titleEn: 'Pharaoh’s Pathfinder',
      titleAr: 'رائد دروب الفراعنة',
    ),
    GamificationLevel(
      number: 19,
      minimumPoints: 8500,
      titleEn: 'Grand Egypt Explorer',
      titleAr: 'مستكشف مصر العظيم',
    ),
    GamificationLevel(
      number: 20,
      minimumPoints: 9700,
      titleEn: 'Royal Historian',
      titleAr: 'المؤرخ الملكي',
    ),
    GamificationLevel(
      number: 21,
      minimumPoints: 11000,
      titleEn: 'Legend of the Nile',
      titleAr: 'أسطورة النيل',
    ),
    GamificationLevel(
      number: 22,
      minimumPoints: 12300,
      titleEn: 'Eternal Storyteller',
      titleAr: 'راوي الحكايات الخالد',
    ),
    GamificationLevel(
      number: 23,
      minimumPoints: 13600,
      titleEn: 'Mythic Guardian',
      titleAr: 'حارس الأساطير',
    ),
    GamificationLevel(
      number: 24,
      minimumPoints: 14500,
      titleEn: 'Legendary Pharaoh',
      titleAr: 'الفرعون الأسطوري',
    ),
    GamificationLevel(
      number: 25,
      minimumPoints: 15000,
      titleEn: 'Immortal Pharaoh of EgyptLore',
      titleAr: 'فرعون إيجيبت لور الخالد',
    ),
  ];

  static const List<GamificationBadgeDefinition> badgeCatalog = [
    GamificationBadgeDefinition(
      id: 'visit_1',
      nameEn: 'First Steps',
      nameAr: 'الخطوات الأولى',
      descriptionEn: 'Visit your first place.',
      descriptionAr: 'زُر مكانك الأول.',
      iconName: 'place',
      tier: 'bronze',
      metric: GamificationBadgeMetric.placesVisited,
      target: 1,
    ),
    GamificationBadgeDefinition(
      id: 'visit_5',
      nameEn: 'Curious Wanderer',
      nameAr: 'متجول فضولي',
      descriptionEn: 'Visit 5 places.',
      descriptionAr: 'زُر ٥ أماكن.',
      iconName: 'explore',
      tier: 'bronze',
      metric: GamificationBadgeMetric.placesVisited,
      target: 5,
    ),
    GamificationBadgeDefinition(
      id: 'visit_10',
      nameEn: 'Tenfold Explorer',
      nameAr: 'مستكشف العشرة',
      descriptionEn: 'Visit 10 places.',
      descriptionAr: 'زُر ١٠ أماكن.',
      iconName: 'explore',
      tier: 'silver',
      metric: GamificationBadgeMetric.placesVisited,
      target: 10,
    ),
    GamificationBadgeDefinition(
      id: 'visit_25',
      nameEn: 'Trailblazer',
      nameAr: 'رائد الدروب',
      descriptionEn: 'Visit 25 places.',
      descriptionAr: 'زُر ٢٥ مكانًا.',
      iconName: 'explore',
      tier: 'silver',
      metric: GamificationBadgeMetric.placesVisited,
      target: 25,
    ),
    GamificationBadgeDefinition(
      id: 'visit_50',
      nameEn: 'Fifty-place Voyager',
      nameAr: 'رحالة الخمسين مكانًا',
      descriptionEn: 'Visit 50 places.',
      descriptionAr: 'زُر ٥٠ مكانًا.',
      iconName: 'explore',
      tier: 'gold',
      metric: GamificationBadgeMetric.placesVisited,
      target: 50,
    ),
    GamificationBadgeDefinition(
      id: 'visit_75',
      nameEn: 'Heritage Seeker',
      nameAr: 'باحث عن التراث',
      descriptionEn: 'Visit 75 places.',
      descriptionAr: 'زُر ٧٥ مكانًا.',
      iconName: 'explore',
      tier: 'gold',
      metric: GamificationBadgeMetric.placesVisited,
      target: 75,
    ),
    GamificationBadgeDefinition(
      id: 'visit_100',
      nameEn: 'Century of Discovery',
      nameAr: 'مئة اكتشاف',
      descriptionEn: 'Visit 100 places.',
      descriptionAr: 'زُر ١٠٠ مكان.',
      iconName: 'workspace_premium',
      tier: 'gold',
      metric: GamificationBadgeMetric.placesVisited,
      target: 100,
    ),
    GamificationBadgeDefinition(
      id: 'visit_150',
      nameEn: 'Grand Voyager',
      nameAr: 'الرحالة العظيم',
      descriptionEn: 'Visit 150 places.',
      descriptionAr: 'زُر ١٥٠ مكانًا.',
      iconName: 'workspace_premium',
      tier: 'gold',
      metric: GamificationBadgeMetric.placesVisited,
      target: 150,
    ),
    GamificationBadgeDefinition(
      id: 'visit_200',
      nameEn: 'Legendary Explorer',
      nameAr: 'المستكشف الأسطوري',
      descriptionEn: 'Visit 200 places.',
      descriptionAr: 'زُر ٢٠٠ مكان.',
      iconName: 'workspace_premium',
      tier: 'platinum',
      metric: GamificationBadgeMetric.placesVisited,
      target: 200,
    ),
    GamificationBadgeDefinition(
      id: 'visit_250',
      nameEn: 'Keeper of a Thousand Tales',
      nameAr: 'حارس ألف حكاية',
      descriptionEn: 'Visit 250 places.',
      descriptionAr: 'زُر ٢٥٠ مكانًا.',
      iconName: 'workspace_premium',
      tier: 'platinum',
      metric: GamificationBadgeMetric.placesVisited,
      target: 250,
    ),
    GamificationBadgeDefinition(
      id: 'visit_300',
      nameEn: 'Egypt’s Greatest Voyager',
      nameAr: 'أعظم رحالة في مصر',
      descriptionEn: 'Visit 300 places.',
      descriptionAr: 'زُر ٣٠٠ مكان.',
      iconName: 'workspace_premium',
      tier: 'platinum',
      metric: GamificationBadgeMetric.placesVisited,
      target: 300,
    ),
    GamificationBadgeDefinition(
      id: 'alexandria_explorer',
      nameEn: 'Alexandria Explorer',
      nameAr: 'مستكشف الإسكندرية',
      descriptionEn: 'Visit 10 places in Alexandria.',
      descriptionAr: 'زُر ١٠ أماكن في الإسكندرية.',
      iconName: 'location_city',
      tier: 'silver',
      metric: GamificationBadgeMetric.alexandriaVisits,
      target: 10,
    ),
    GamificationBadgeDefinition(
      id: 'pearl_mediterranean',
      nameEn: 'Pearl of the Mediterranean',
      nameAr: 'لؤلؤة البحر المتوسط',
      descriptionEn: 'Visit 40 places in Alexandria.',
      descriptionAr: 'زُر ٤٠ مكانًا في الإسكندرية.',
      iconName: 'location_city',
      tier: 'gold',
      metric: GamificationBadgeMetric.alexandriaVisits,
      target: 40,
    ),
    GamificationBadgeDefinition(
      id: 'cairo_giza_explorer',
      nameEn: 'Cairo & Giza Explorer',
      nameAr: 'مستكشف القاهرة والجيزة',
      descriptionEn: 'Visit 25 places in Cairo and Giza.',
      descriptionAr: 'زُر ٢٥ مكانًا في القاهرة والجيزة.',
      iconName: 'location_city',
      tier: 'silver',
      metric: GamificationBadgeMetric.cairoGizaVisits,
      target: 25,
    ),
    GamificationBadgeDefinition(
      id: 'guardian_pyramids',
      nameEn: 'Guardian of the Pyramids',
      nameAr: 'حارس الأهرامات',
      descriptionEn: 'Visit 100 places in Cairo and Giza.',
      descriptionAr: 'زُر ١٠٠ مكان في القاهرة والجيزة.',
      iconName: 'location_city',
      tier: 'platinum',
      metric: GamificationBadgeMetric.cairoGizaVisits,
      target: 100,
    ),
    GamificationBadgeDefinition(
      id: 'upper_egypt_pioneer',
      nameEn: 'Upper Egypt Pioneer',
      nameAr: 'رائد صعيد مصر',
      descriptionEn: 'Visit 25 places in Luxor and Aswan.',
      descriptionAr: 'زُر ٢٥ مكانًا في الأقصر وأسوان.',
      iconName: 'location_city',
      tier: 'silver',
      metric: GamificationBadgeMetric.upperEgyptVisits,
      target: 25,
    ),
    GamificationBadgeDefinition(
      id: 'lord_thebes_nubia',
      nameEn: 'Lord of Thebes & Nubia',
      nameAr: 'سيد طيبة والنوبة',
      descriptionEn: 'Visit 80 places in Luxor and Aswan.',
      descriptionAr: 'زُر ٨٠ مكانًا في الأقصر وأسوان.',
      iconName: 'location_city',
      tier: 'gold',
      metric: GamificationBadgeMetric.upperEgyptVisits,
      target: 80,
    ),
    GamificationBadgeDefinition(
      id: 'grand_master_egyptlore',
      nameEn: 'Grand Master of EgyptLore',
      nameAr: 'المعلم الأكبر لإيجيبت لور',
      descriptionEn:
          'Visit places in Alexandria, Cairo & Giza, and Upper Egypt.',
      descriptionAr: 'زُر أماكن في الإسكندرية والقاهرة والجيزة وصعيد مصر.',
      iconName: 'public',
      tier: 'platinum',
      metric: GamificationBadgeMetric.allRegions,
      target: 3,
    ),
    GamificationBadgeDefinition(
      id: 'first_checkin',
      nameEn: 'First Check-in',
      nameAr: 'أول تسجيل زيارة',
      descriptionEn: 'Check in at your first place.',
      descriptionAr: 'سجّل زيارتك الأولى لمكان.',
      iconName: 'check_circle',
      tier: 'bronze',
      metric: GamificationBadgeMetric.placesVisited,
      target: 1,
    ),
    GamificationBadgeDefinition(
      id: 'tour_finisher_1',
      nameEn: 'Tour Finisher',
      nameAr: 'منهي الجولات',
      descriptionEn: 'Complete 1 tour.',
      descriptionAr: 'أكمل جولة واحدة.',
      iconName: 'route',
      tier: 'bronze',
      metric: GamificationBadgeMetric.toursCompleted,
      target: 1,
    ),
    GamificationBadgeDefinition(
      id: 'tour_finisher_5',
      nameEn: 'Tour Finisher: Five Tours',
      nameAr: 'منهي خمس جولات',
      descriptionEn: 'Complete 5 tours.',
      descriptionAr: 'أكمل ٥ جولات.',
      iconName: 'route',
      tier: 'silver',
      metric: GamificationBadgeMetric.toursCompleted,
      target: 5,
    ),
    GamificationBadgeDefinition(
      id: 'tour_finisher_10',
      nameEn: 'Tour Finisher: Ten Tours',
      nameAr: 'منهي عشر جولات',
      descriptionEn: 'Complete 10 tours.',
      descriptionAr: 'أكمل ١٠ جولات.',
      iconName: 'route',
      tier: 'gold',
      metric: GamificationBadgeMetric.toursCompleted,
      target: 10,
    ),
    GamificationBadgeDefinition(
      id: 'ai_historian',
      nameEn: 'AI Historian',
      nameAr: 'مؤرخ الذكاء الاصطناعي',
      descriptionEn: 'Ask the AI historian your first question.',
      descriptionAr: 'اطرح سؤالك الأول على المؤرخ الذكي.',
      iconName: 'psychology',
      tier: 'bronze',
      metric: GamificationBadgeMetric.aiHistorian,
      target: 1,
    ),
    GamificationBadgeDefinition(
      id: 'streak_3_days',
      nameEn: 'Streak: 3 Days',
      nameAr: 'سلسلة ٣ أيام',
      descriptionEn: 'Keep your visit streak for 3 days.',
      descriptionAr: 'حافظ على سلسلة زياراتك لمدة ٣ أيام.',
      iconName: 'local_fire_department',
      tier: 'bronze',
      metric: GamificationBadgeMetric.streakDays,
      target: 3,
    ),
    GamificationBadgeDefinition(
      id: 'streak_7_days',
      nameEn: 'Streak: 7 Days',
      nameAr: 'سلسلة ٧ أيام',
      descriptionEn: 'Keep your visit streak for 7 days.',
      descriptionAr: 'حافظ على سلسلة زياراتك لمدة ٧ أيام.',
      iconName: 'local_fire_department',
      tier: 'silver',
      metric: GamificationBadgeMetric.streakDays,
      target: 7,
    ),
    GamificationBadgeDefinition(
      id: 'streak_14_days',
      nameEn: 'Streak: 14 Days',
      nameAr: 'سلسلة ١٤ يومًا',
      descriptionEn: 'Keep your visit streak for 14 days.',
      descriptionAr: 'حافظ على سلسلة زياراتك لمدة ١٤ يومًا.',
      iconName: 'local_fire_department',
      tier: 'gold',
      metric: GamificationBadgeMetric.streakDays,
      target: 14,
    ),
    GamificationBadgeDefinition(
      id: 'streak_30_days',
      nameEn: 'Streak: 30 Days',
      nameAr: 'سلسلة ٣٠ يومًا',
      descriptionEn: 'Keep your visit streak for 30 days.',
      descriptionAr: 'حافظ على سلسلة زياراتك لمدة ٣٠ يومًا.',
      iconName: 'local_fire_department',
      tier: 'platinum',
      metric: GamificationBadgeMetric.streakDays,
      target: 30,
    ),
  ];
}
