class OfflinePack {
  final String id;
  final String name;
  final String description;
  final String? nameAr;
  final String? descriptionAr;
  final String governorateId;

  final List<String> placeIds;

  final List<String> categories;
  final double sizeMb;
  final int downloadedCount;
  final int placesCount;
  final int toursCount;
  final int cachedImagesCount;
  final DateTime? downloadedAt;
  final String coverEmoji;

  const OfflinePack({
    required this.id,
    required this.name,
    required this.description,
    this.nameAr,
    this.descriptionAr,
    this.governorateId = 'alexandria',
    this.placeIds = const [],
    this.categories = const [],
    this.sizeMb = 0,
    this.downloadedCount = 0,
    this.placesCount = 0,
    this.toursCount = 0,
    this.cachedImagesCount = 0,
    this.downloadedAt,
    this.coverEmoji = '',
  });

  bool get isDownloaded => downloadedAt != null;
  String get storageKey => '$governorateId::$id';

  String localizedName(String locale) =>
      locale == 'ar' && nameAr != null && nameAr!.isNotEmpty ? nameAr! : name;

  String localizedDescription(String locale) =>
      locale == 'ar' && descriptionAr != null && descriptionAr!.isNotEmpty
      ? descriptionAr!
      : description;

  OfflinePack copyWith({
    DateTime? downloadedAt,
    int? downloadedCount,
    int? placesCount,
    int? toursCount,
    int? cachedImagesCount,
    double? sizeMb,
  }) => OfflinePack(
    id: id,
    name: name,
    description: description,
    nameAr: nameAr,
    descriptionAr: descriptionAr,
    governorateId: governorateId,
    placeIds: placeIds,
    categories: categories,
    sizeMb: sizeMb ?? this.sizeMb,
    downloadedCount: downloadedCount ?? this.downloadedCount,
    placesCount: placesCount ?? this.placesCount,
    toursCount: toursCount ?? this.toursCount,
    cachedImagesCount: cachedImagesCount ?? this.cachedImagesCount,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    coverEmoji: coverEmoji,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'name_ar': nameAr,
    'description_ar': descriptionAr,
    'governorate_id': governorateId,
    'place_ids': placeIds,
    'categories': categories,
    'size_mb': sizeMb,
    'downloaded_count': downloadedCount,
    'places_count': placesCount,
    'tours_count': toursCount,
    'cached_images_count': cachedImagesCount,
    'downloaded_at': downloadedAt?.toIso8601String(),
    'cover_emoji': coverEmoji,
  };

  factory OfflinePack.fromJson(Map<String, dynamic> json) => OfflinePack(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    nameAr: json['name_ar'] as String?,
    descriptionAr: json['description_ar'] as String?,
    governorateId: (json['governorate_id'] as String?) ?? 'alexandria',
    placeIds: ((json['place_ids'] as List<dynamic>?) ?? const [])
        .cast<String>(),
    categories: ((json['categories'] as List<dynamic>?) ?? const [])
        .cast<String>(),
    sizeMb: (json['size_mb'] as num?)?.toDouble() ?? 0,
    downloadedCount: (json['downloaded_count'] as num?)?.toInt() ?? 0,
    placesCount:
        (json['places_count'] as num?)?.toInt() ??
        (json['downloaded_count'] as num?)?.toInt() ??
        0,
    toursCount: (json['tours_count'] as num?)?.toInt() ?? 0,
    cachedImagesCount: (json['cached_images_count'] as num?)?.toInt() ?? 0,
    downloadedAt: json['downloaded_at'] == null
        ? null
        : DateTime.parse(json['downloaded_at'] as String),
    coverEmoji: json['cover_emoji'] as String? ?? '',
  );
}
