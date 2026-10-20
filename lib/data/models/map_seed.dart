import 'package:flutter/material.dart';

import '../models/place_model.dart';
import 'map_poi.dart';

List<MapPoi> getSeedHotels() => _hotels;

List<PlaceModel> getSeedHotelPlaces() => _hotelPlaces;

List<MapPoi> _hotels = const [
  MapPoi(
    id: 'hotel-four-seasons',
    name: 'Four Seasons Hotel Alexandria',
    address: '399 El Geish Rd, San Stefano',
    lat: 31.2452,
    lng: 29.9659,
    category: 'hotel',
    brand: 'Four Seasons',
    stars: 5,
    icon: Icons.hotel_class_rounded,
    color: Color(0xFFC8A24B),
  ),
  MapPoi(
    id: 'hotel-sofitel-alex',
    name: 'Sofitel Alexandria Cecil',
    address: '16 Kaied Abdul Latif, Manshia',
    lat: 31.1989,
    lng: 29.9089,
    category: 'hotel',
    brand: 'Sofitel',
    stars: 4,
    icon: Icons.hotel_rounded,
    color: Color(0xFFB7003F),
  ),
  MapPoi(
    id: 'hotel-steigenberger-cerine',
    name: 'Steigenberger Cecil - Cerine',
    address: 'El Geish Rd, San Stefano',
    lat: 31.2441,
    lng: 29.9667,
    category: 'hotel',
    brand: 'Steigenberger',
    stars: 5,
    icon: Icons.hotel_class_rounded,
    color: Color(0xFF8A6E2F),
  ),
  MapPoi(
    id: 'hotel-tolip-alex',
    name: 'Tolip Alexandria',
    address: 'Moustafa Kamel, Corniche Rd',
    lat: 31.1998,
    lng: 29.9321,
    category: 'hotel',
    brand: 'Tolip',
    stars: 4,
    icon: Icons.hotel_rounded,
    color: Color(0xFF1E5A8A),
  ),
  MapPoi(
    id: 'hotel-paradise',
    name: 'Paradise Inn Hotel',
    address: '221 Sultan Hussein St, Anfushi',
    lat: 31.2130,
    lng: 29.8912,
    category: 'hotel',
    brand: 'Paradise',
    stars: 3,
    icon: Icons.hotel_rounded,
    color: Color(0xFFE91E63),
  ),
  MapPoi(
    id: 'hotel-romance-alex',
    name: 'Romance Alexandria Hotel',
    address: '303 El Geish Rd, Roushdy',
    lat: 31.2395,
    lng: 29.9592,
    category: 'hotel',
    brand: 'Romance',
    stars: 4,
    icon: Icons.hotel_rounded,
    color: Color(0xFF673AB7),
  ),
  MapPoi(
    id: 'hotel-cherry',
    name: 'Cherry Maryski Hotel',
    address: '9 El Borsa El Kadeem St, Manshia',
    lat: 31.2001,
    lng: 29.9119,
    category: 'hotel',
    brand: 'Cherry',
    stars: 3,
    icon: Icons.hotel_rounded,
    color: Color(0xFFD81B60),
  ),
  MapPoi(
    id: 'hotel-plaza-alex',
    name: 'Plaza Hotel Alexandria',
    address: '394 El-Gaish Rd, Zizinia, San Stefano',
    lat: 31.2448,
    lng: 29.9647,
    category: 'hotel',
    brand: 'Plaza',
    stars: 3,
    icon: Icons.hotel_rounded,
    color: Color(0xFF00897B),
  ),
  MapPoi(
    id: 'hotel-king-mariout',
    name: 'King Mariout Hotel',
    address: 'Km 14, Alexandria-Cairo Desert Rd',
    lat: 31.0268,
    lng: 29.7701,
    category: 'hotel',
    brand: 'King Mariout',
    stars: 4,
    icon: Icons.hotel_rounded,
    color: Color(0xFF5D4037),
  ),
  MapPoi(
    id: 'hotel-san-stefano',
    name: 'San Stefano Grand Plaza',
    address: 'El Geish Rd, San Stefano',
    lat: 31.2449,
    lng: 29.9655,
    category: 'hotel',
    brand: 'San Stefano',
    stars: 5,
    icon: Icons.hotel_class_rounded,
    color: Color(0xFF455A64),
  ),
  MapPoi(
    id: 'hotel-downtown',
    name: 'Downtown Hotel Alexandria',
    address: '5 Mesaha Sq, Roushdy',
    lat: 31.2388,
    lng: 29.9618,
    category: 'hotel',
    brand: 'Downtown',
    stars: 3,
    icon: Icons.hotel_rounded,
    color: Color(0xFF2E7D32),
  ),
  MapPoi(
    id: 'hotel-borg-al-arab',
    name: 'Borg El Arab Airport Hotel',
    address: 'Borg El Arab International Airport',
    lat: 30.9187,
    lng: 29.6946,
    category: 'hotel',
    brand: 'Borg',
    stars: 3,
    icon: Icons.hotel_rounded,
    color: Color(0xFF3F51B5),
  ),
];

// Each seeded hotel has its own image hosted in public Supabase Storage.
const Map<String, String> _hotelImageById = {
  'hotel-four-seasons':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-four-seasons.jpg",
  'hotel-sofitel-alex':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-sofitel-alex.jpg",
  'hotel-steigenberger-cerine':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-steigenberger-cerine.jpg",
  'hotel-tolip-alex':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-tolip-alex.jpg",
  'hotel-paradise':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-paradise.jpg",
  'hotel-romance-alex':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-romance-alex.jpg",
  'hotel-cherry':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-cherry.jpg",
  'hotel-plaza-alex':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-plaza-alex.jpg",
  'hotel-king-mariout':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-king-mariout.jpg",
  'hotel-san-stefano':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-san-stefano.jpg",
  'hotel-downtown':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-downtown.jpg",
  'hotel-borg-al-arab':
      "https://tbivoxyxclwjjspwsgvc.supabase.co/storage/v1/object/public/place-images/hotels/hotel-borg-al-arab.jpg",
};

List<PlaceModel> _hotelPlaces = _hotels
    .map(
      (poi) => PlaceModel(
        id: poi.id,
        nameEn: poi.name,
        nameAr: null,
        descriptionEn:
            '${poi.brand ?? "Hotel"} is located at ${poi.address} in Alexandria.',
        descriptionAr: null,
        imageUrl: _hotelImageById[poi.id] ?? '',
        rating: (poi.stars ?? 3).toDouble(),
        category: 'Hotels',
        categoryAr: 'فنادق',
        lat: poi.lat,
        lng: poi.lng,
        address: poi.address,
        addressAr: null,
        openHours: 'Open 24 hours',
        reviewCount: 0,
        priceLevel: poi.stars != null && poi.stars! >= 4
            ? PriceLevel.expensive
            : PriceLevel.moderate,
        priceNote: poi.stars != null && poi.stars! >= 4
            ? 'EGP ${3000 + (poi.stars ?? 3) * 1500}+ / night'
            : 'EGP ${800 + (poi.stars ?? 3) * 500}+ / night',
        priceNoteAr: null,
        priceLocalEgp: 1500,
        priceForeignerEgp: 4500,
        isHiddenGem: false,
        bestTimeNote: null,
        bestTimeToVisit: null,
        isIndoor: true,
      ),
    )
    .toList(growable: false);
