import 'package:flutter/material.dart';

/// Lightweight POI used by the map for non-historical layers:
/// ATMs and hotels. Both share the same shape so the map can
/// render them with a uniform MarkerLayer treatment.
class MapPoi {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category; // 'atm' or 'hotel'
  /// Free-form sub-tag used for marker styling — for ATMs the bank
  /// name (CIB, NBE, etc.), for hotels the brand or star level.
  final String? brand;
  final int? stars;
  final IconData icon;
  final Color color;

  const MapPoi({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.brand,
    this.stars,
    required this.icon,
    required this.color,
  });
}
