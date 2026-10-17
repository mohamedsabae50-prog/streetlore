import 'place_model.dart';

class ItineraryModel {
  final String id;
  final String title;
  final String? titleAr;
  final String description;
  final String? descriptionAr;
  final String duration;
  final String? durationAr;
  final String imageUrl;
  final String status;
  final bool isPremium;
  final bool isHiddenGem;
  final List<PlaceModel> places;
  const ItineraryModel({
    required this.id,
    required this.title,
    this.titleAr,
    required this.description,
    this.descriptionAr,
    required this.duration,
    this.durationAr,
    required this.imageUrl,
    this.status = 'published',
    this.isPremium = false,
    this.isHiddenGem = false,
    required this.places,
  });

  bool get requiresPro => isPremium || isHiddenGem;

  String? get coverImageUrl {
    String? validUrl(String candidate) {
      final value = candidate.trim();
      final uri = Uri.tryParse(value);
      return uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty
          ? value
          : null;
    }

    final cover = validUrl(imageUrl);
    final placeImages = places
        .map((place) => validUrl(place.primaryImage))
        .whereType<String>()
        .toList(growable: false);
    if (cover != null && placeImages.contains(cover)) return cover;
    if (placeImages.isNotEmpty) return placeImages.first;
    return places.isEmpty ? cover : null;
  }

  String localizedTitle(String locale) {
    if (locale == 'ar' && titleAr != null && titleAr!.isNotEmpty) {
      return titleAr!;
    }
    return title;
  }

  String localizedDescription(String locale) {
    if (locale == 'ar' && descriptionAr != null && descriptionAr!.isNotEmpty) {
      return descriptionAr!;
    }
    return description;
  }

  String localizedDuration(String locale) {
    if (locale == 'ar' && durationAr != null && durationAr!.isNotEmpty) {
      return durationAr!;
    }
    if (locale == 'ar') {
      final durationText = duration.trim();
      if (durationText.toLowerCase() == 'full day') return 'يوم كامل';
      if (durationText.toLowerCase() == 'half day') return 'نصف يوم';
      final hours = RegExp(
        r'^(\d+)\s*hours?$',
        caseSensitive: false,
      ).firstMatch(durationText);
      if (hours != null) {
        final count = int.parse(hours.group(1)!);
        return switch (count) {
          1 => 'ساعة واحدة',
          2 => 'ساعتان',
          >= 3 && <= 10 => '$count ساعات',
          _ => '$count ساعة',
        };
      }
    }
    return duration;
  }

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      id: json['id'] as String,
      title:
          json['title_en'] as String? ??
          json['title'] as String? ??
          json['titleEn'] as String? ??
          '',
      titleAr:
          json['title_ar'] as String? ??
          json['titleAr'] as String?,
      description:
          json['description_en'] as String? ??
          json['description'] as String? ??
          json['descriptionEn'] as String? ??
          '',
      descriptionAr:
          json['description_ar'] as String? ?? json['descriptionAr'] as String?,
      duration:
          json['duration_en'] as String? ??
          json['duration'] as String? ??
          json['durationEn'] as String? ??
          '',
      durationAr:
          json['duration_ar'] as String? ?? json['durationAr'] as String?,
      imageUrl:
          (json['imageUrl'] as String?) ?? (json['image_url'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'published',
      isPremium:
          (json['is_premium'] as bool?) ??
          (json['isPremium'] as bool?) ??
          (json['premium'] as bool?) ??
          false,
      isHiddenGem:
          (json['is_hidden_gem'] as bool?) ??
          (json['isHiddenGem'] as bool?) ??
          (json['hidden_gem'] as bool?) ??
          false,
      places:
          (json['places'] as List<dynamic>?)
              ?.map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'titleAr': titleAr,
      'description': description,
      'descriptionAr': descriptionAr,
      'duration': duration,
      'durationAr': durationAr,
      'imageUrl': imageUrl,
      'status': status,
      'isPremium': isPremium,
      'isHiddenGem': isHiddenGem,
      'places': places.map((e) => e.toJson()).toList(),
    };
  }
}
