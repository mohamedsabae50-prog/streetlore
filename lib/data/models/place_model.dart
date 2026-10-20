enum PriceLevel {
  free,
  cheap,
  moderate,
  expensive;

  String get label {
    switch (this) {
      case PriceLevel.free:
        return 'Free';
      case PriceLevel.cheap:
        return 'EGP 25-50';
      case PriceLevel.moderate:
        return 'EGP 50-150';
      case PriceLevel.expensive:
        return 'EGP 150+';
    }
  }

  static PriceLevel fromName(String? name) {
    switch (name) {
      case 'cheap':
        return PriceLevel.cheap;
      case 'moderate':
        return PriceLevel.moderate;
      case 'expensive':
        return PriceLevel.expensive;
      case 'free':
      default:
        return PriceLevel.free;
    }
  }
}

class PlaceModel {
  final String id;
  final String nameEn;
  final String? nameAr;
  final String descriptionEn;
  final String? descriptionAr;
  final String imageUrl;
  final List<String> imageUrls;
  final double rating;
  final String category;
  final String? categoryAr;
  final double lat;
  final double lng;
  final String address;
  final String? addressAr;
  final String governorate;
  final String openHours;
  final int reviewCount;
  final PriceLevel priceLevel;
  final String priceNote;
  final String? priceNoteAr;
  final bool isHiddenGem;
  final int? priceLocalEgp;
  final int? priceForeignerEgp;

  final int displayOrder;

  final Map<String, int>? bestTimeOverride;

  final String? bestTimeNote;

  final String? bestTimeToVisit;

  final bool isIndoor;

  final bool enableChat;

  final bool enableGallery;

  const PlaceModel({
    required this.id,
    required this.nameEn,
    this.nameAr,
    required this.descriptionEn,
    this.descriptionAr,
    required this.imageUrl,
    this.imageUrls = const <String>[],
    required this.rating,
    this.category = 'General',
    this.categoryAr,
    required this.lat,
    required this.lng,
    this.address = 'Alexandria, Egypt',
    this.addressAr,
    this.governorate = 'alexandria',
    this.openHours = '9:00 AM - 6:00 PM',
    this.reviewCount = 0,
    this.priceLevel = PriceLevel.free,
    this.priceNote = '',
    this.priceNoteAr,
    this.isHiddenGem = false,
    this.priceLocalEgp,
    this.priceForeignerEgp,
    this.displayOrder = 999,
    this.bestTimeOverride,
    this.bestTimeNote,
    this.bestTimeToVisit,
    this.isIndoor = false,
    this.enableChat = true,
    this.enableGallery = true,
  });

  String _pick(String en, String? ar, String locale) {
    if (locale == 'ar' && ar != null && ar.isNotEmpty) return ar;
    return en;
  }

  String localizedName(String locale) => _pick(nameEn, nameAr, locale);
  String localizedDescription(String locale) =>
      _pick(descriptionEn, descriptionAr, locale);
  String localizedCategory(String locale) =>
      _pick(category, categoryAr, locale);
  String localizedAddress(String locale) => _pick(address, addressAr, locale);
  String localizedPriceNote(String locale) =>
      _pick(priceNote, priceNoteAr, locale);

  bool get isFree => priceLevel == PriceLevel.free;

  bool get hasDualPrice => priceLocalEgp != null && priceForeignerEgp != null;

  /// All official images for this place, in display order.
  /// Falls back to [imageUrl] when [imageUrls] is empty (so older rows
  /// or pre-migration places still render correctly).
  List<String> get officialImages {
    final list = <String>[];
    final seen = <String>{};
    for (final value in [imageUrl, ...imageUrls]) {
      final url = value.trim();
      if (url.isNotEmpty && seen.add(url)) {
        list.add(url);
      }
    }
    return list;
  }

  String get primaryImage =>
      officialImages.isNotEmpty ? officialImages.first : imageUrl;

  static String _stringValue(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is String) {
        if (value.isNotEmpty) return value;
        continue;
      }
      return value.toString();
    }
    return fallback;
  }

  static int _intValue(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static double _doubleValue(
    Map<String, dynamic> json,
    List<String> keys, {
    double fallback = 0.0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _boolValue(
    Map<String, dynamic> json,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        if (lowered == 'true') return true;
        if (lowered == 'false') return false;
      }
    }
    return fallback;
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    Map<String, int>? bestTimeOverride;
    final raw = json['best_time_override'];
    if (raw is Map) {
      bestTimeOverride = raw.map(
        (k, v) => MapEntry(k.toString(), (v is num ? v.toInt() : 0)),
      );
    }
    final urlsRaw =
        json['image_urls'] ?? json['imageUrls'] ?? json['image_url'];
    List<String> urls = const <String>[];
    if (urlsRaw is List) {
      urls = urlsRaw
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    } else if (urlsRaw is String && urlsRaw.isNotEmpty) {
      urls = [urlsRaw.trim()];
    }
    final governorate = _stringValue(json, [
      'governorate',
    ], fallback: 'alexandria').trim();
    return PlaceModel(
      id: _stringValue(json, ['id'], fallback: ''),
      nameEn: _stringValue(json, ['name_en', 'name', 'nameEn'], fallback: ''),
      nameAr: _stringValue(json, ['name_ar', 'nameAr']),
      descriptionEn: _stringValue(json, [
        'description_en',
        'description',
        'descriptionEn',
      ], fallback: ''),
      descriptionAr: _stringValue(json, ['description_ar', 'descriptionAr']),
      imageUrl: _stringValue(json, ['imageUrl', 'image_url'], fallback: ''),
      imageUrls: urls,
      rating: _doubleValue(json, ['rating'], fallback: 0.0),
      category: _stringValue(json, ['category'], fallback: 'General'),
      categoryAr: _stringValue(json, ['category_ar', 'categoryAr']),
      lat: _doubleValue(json, ['lat'], fallback: 0.0),
      lng: _doubleValue(json, ['lng'], fallback: 0.0),
      address: _stringValue(json, ['address'], fallback: 'Alexandria, Egypt'),
      addressAr: _stringValue(json, ['address_ar', 'addressAr']),
      governorate: governorate.isEmpty
          ? 'alexandria'
          : governorate.toLowerCase(),
      openHours: _stringValue(json, [
        'openHours',
        'open_hours',
      ], fallback: '9:00 AM - 6:00 PM'),
      reviewCount: _intValue(json, [
        'reviewCount',
        'review_count',
      ], fallback: 0),
      priceLevel: PriceLevel.fromName(
        _stringValue(json, ['priceLevel', 'price_level']),
      ),
      priceNote: _stringValue(json, ['priceNote', 'price_note'], fallback: ''),
      priceNoteAr: _stringValue(json, ['price_note_ar', 'priceNoteAr']),
      isHiddenGem: _boolValue(json, [
        'isHiddenGem',
        'is_hidden_gem',
      ], fallback: false),
      priceLocalEgp: _intValue(json, ['priceLocalEgp', 'price_local_egp']),
      priceForeignerEgp: _intValue(json, [
        'priceForeignerEgp',
        'price_foreigner_egp',
      ]),
      displayOrder: _intValue(json, ['display_order'], fallback: 999),
      bestTimeOverride: bestTimeOverride,
      bestTimeNote: _stringValue(json, ['best_time_note']),
      bestTimeToVisit: _stringValue(json, ['best_time_to_visit']),
      isIndoor: _boolValue(json, ['is_indoor'], fallback: false),
      enableChat: _boolValue(json, [
        'enable_chat',
        'is_chat_enabled',
      ], fallback: true),
      enableGallery: _boolValue(json, ['enable_gallery'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ar': nameAr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'imageUrl': imageUrl,
      'image_urls': imageUrls,
      'rating': rating,
      'category': category,
      'category_ar': categoryAr,
      'lat': lat,
      'lng': lng,
      'address': address,
      'address_ar': addressAr,
      'governorate': governorate,
      'openHours': openHours,
      'reviewCount': reviewCount,
      'priceLevel': priceLevel.name,
      'priceNote': priceNote,
      'price_note_ar': priceNoteAr,
      'isHiddenGem': isHiddenGem,
      'priceLocalEgp': priceLocalEgp,
      'priceForeignerEgp': priceForeignerEgp,
      'best_time_override': bestTimeOverride,
      'best_time_note': bestTimeNote,
      'best_time_to_visit': bestTimeToVisit,
      'is_indoor': isIndoor,
      'enable_chat': enableChat,
      'enable_gallery': enableGallery,
    };
  }

  PlaceModel copyWith({
    String? id,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? imageUrl,
    double? rating,
    String? category,
    String? categoryAr,
    double? lat,
    double? lng,
    String? address,
    String? addressAr,
    String? governorate,
    String? openHours,
    int? reviewCount,
    PriceLevel? priceLevel,
    String? priceNote,
    String? priceNoteAr,
    bool? isHiddenGem,
    int? priceLocalEgp,
    int? priceForeignerEgp,
    Map<String, int>? bestTimeOverride,
    String? bestTimeNote,
    String? bestTimeToVisit,
    bool? isIndoor,
    bool? enableChat,
    bool? enableGallery,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      category: category ?? this.category,
      categoryAr: categoryAr ?? this.categoryAr,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      addressAr: addressAr ?? this.addressAr,
      governorate: governorate ?? this.governorate,
      openHours: openHours ?? this.openHours,
      reviewCount: reviewCount ?? this.reviewCount,
      priceLevel: priceLevel ?? this.priceLevel,
      priceNote: priceNote ?? this.priceNote,
      priceNoteAr: priceNoteAr ?? this.priceNoteAr,
      isHiddenGem: isHiddenGem ?? this.isHiddenGem,
      priceLocalEgp: priceLocalEgp ?? this.priceLocalEgp,
      priceForeignerEgp: priceForeignerEgp ?? this.priceForeignerEgp,
      bestTimeOverride: bestTimeOverride ?? this.bestTimeOverride,
      bestTimeNote: bestTimeNote ?? this.bestTimeNote,
      bestTimeToVisit: bestTimeToVisit ?? this.bestTimeToVisit,
      isIndoor: isIndoor ?? this.isIndoor,
      enableChat: enableChat ?? this.enableChat,
      enableGallery: enableGallery ?? this.enableGallery,
    );
  }
}
