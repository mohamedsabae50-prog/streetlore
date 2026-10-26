import '../../data/models/place_model.dart';

Uri googleMapsSearchUri(PlaceModel place, {String? locale}) {
  final cleanName = cleanPlaceName(place.localizedName(locale ?? 'en'));
  final governorate = place.governorate
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$cleanName, $governorate, Egypt',
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
