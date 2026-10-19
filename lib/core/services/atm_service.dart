import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/models/map_poi.dart';

class AtmService {
  AtmService._();

  static Future<List<MapPoi>> fetchNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 2500,
  }) async {
    final query =
        '[out:json][timeout:20];node["amenity"="atm"]'
        '(around:$radiusMeters,$latitude,$longitude);out body;';
    final uri = Uri.https('overpass-api.de', '/api/interpreter', {
      'data': query,
    });
    final response = await http
        .get(
          uri,
          headers: const {'User-Agent': 'StreetLore/1.0 (Alexandria guide)'},
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Overpass API returned HTTP ${response.statusCode}.',
        uri,
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['elements'] is! List) {
      throw const FormatException('Overpass returned an invalid ATM response.');
    }

    const brandColors = <String, Color>{
      'CIB': Color(0xFFED1C24),
      'NBE': Color(0xFF0033A0),
      'QNB': Color(0xFF8B1A1A),
      'Banque Misr': Color(0xFF1F4E79),
      'Alex Bank': Color(0xFFB22222),
      'HSBC': Color(0xFFDB0011),
      'Arab Bank': Color(0xFF00695C),
    };
    final atms = <MapPoi>[];
    for (final element in payload['elements'] as List) {
      if (element is! Map || element['lat'] is! num || element['lon'] is! num) {
        continue;
      }
      final tags = element['tags'];
      if (tags is! Map) continue;
      final lat = (element['lat'] as num).toDouble();
      final lng = (element['lon'] as num).toDouble();
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      final name = (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? 'ATM')
          .toString()
          .trim();
      final brand = (tags['brand'] ?? tags['operator'])?.toString();
      final street = tags['addr:street']?.toString();
      final houseNumber = tags['addr:housenumber']?.toString();
      final address = [
        if (houseNumber != null && houseNumber.isNotEmpty) houseNumber,
        if (street != null && street.isNotEmpty) street,
      ].join(' ');
      var color = const Color(0xFF15803D);
      for (final entry in brandColors.entries) {
        if (brand?.toLowerCase().contains(entry.key.toLowerCase()) == true) {
          color = entry.value;
          break;
        }
      }
      atms.add(
        MapPoi(
          id: 'osm-atm-${element['id']}',
          name: name,
          address: address.isEmpty ? 'OpenStreetMap location' : address,
          lat: lat,
          lng: lng,
          category: 'atm',
          brand: brand,
          icon: Icons.atm_rounded,
          color: color,
        ),
      );
    }
    return atms;
  }
}
