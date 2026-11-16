import '../../data/models/place_model.dart';

Uri googleMapsSearchUri(PlaceModel place, {String? locale}) {
  if (!place.lat.isFinite ||
      !place.lng.isFinite ||
      place.lat < -90 ||
      place.lat > 90 ||
      place.lng < -180 ||
      place.lng > 180) {
    throw ArgumentError.value(
      (place.lat, place.lng),
      'place coordinates',
      'must be valid latitude and longitude',
    );
  }
  final cleanName = cleanPlaceName(place.localizedName(locale ?? 'en'));
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$cleanName @ ${place.lat},${place.lng}',
  });
}

String cleanPlaceName(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  words.removeWhere(
    (word) => word.contains('+') && RegExp(r'\d').hasMatch(word),
  );
  while (words.isNotEmpty && RegExp(r'\d').hasMatch(words.first)) {
    words.removeAt(0);
  }
  while (words.isNotEmpty && RegExp(r'\d').hasMatch(words.last)) {
    words.removeLast();
  }
  return words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
