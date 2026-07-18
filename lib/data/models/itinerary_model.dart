import 'place_model.dart';

class ItineraryModel {
  final String id;
  final String title;
  final String description;
  final String duration;
  final String imageUrl;
  final List<PlaceModel> places;
  const ItineraryModel({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.imageUrl,
    required this.places,
  });
  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      duration: json['duration'] as String,
      imageUrl: json['imageUrl'] as String,
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
      'description': description,
      'duration': duration,
      'imageUrl': imageUrl,
      'places': places.map((e) => e.toJson()).toList(),
    };
  }
}
