import 'dart:convert';
import 'dart:math' as math;

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
        '[out:json][timeout:20];(node["amenity"="atm"]'
        '(around:$radiusMeters,$latitude,$longitude);'
        'way["highway"](around:$radiusMeters,$latitude,$longitude);'
        ');out body geom;';
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

    final elements = payload['elements'] as List;
    final roads = elements
        .whereType<Map>()
        .where((element) => element['type'] == 'way')
        .map((element) => element['geometry'])
        .whereType<List>()
        .map((geometry) => geometry.whereType<Map>().toList(growable: false))
        .toList(growable: false);

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
    for (final element in elements) {
      if (element is! Map || element['lat'] is! num || element['lon'] is! num) {
        continue;
      }
      if (element['type'] != 'node') continue;
      final tags = element['tags'];
      if (tags is! Map) continue;
      final lat = (element['lat'] as num).toDouble();
      final lng = (element['lon'] as num).toDouble();
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      if (!isWithinStreetDistance(
        latitude: lat,
        longitude: lng,
        roadGeometries: roads,
      )) {
        continue;
      }
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

  static bool isWithinStreetDistance({
    required double latitude,
    required double longitude,
    required List<List<Map>> roadGeometries,
    double maxDistanceMeters = 40,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !maxDistanceMeters.isFinite ||
        maxDistanceMeters < 0) {
      return false;
    }
    final cosLatitude = math.cos(latitude * math.pi / 180);
    for (final geometry in roadGeometries) {
      for (var index = 1; index < geometry.length; index++) {
        final start = geometry[index - 1];
        final end = geometry[index];
        final startLat = (start['lat'] as num?)?.toDouble();
        final startLng = (start['lon'] as num?)?.toDouble();
        final endLat = (end['lat'] as num?)?.toDouble();
        final endLng = (end['lon'] as num?)?.toDouble();
        if (startLat == null ||
            startLng == null ||
            endLat == null ||
            endLng == null) {
          continue;
        }

        final startX = (startLng - longitude) * cosLatitude * 111320;
        final startY = (startLat - latitude) * 111320;
        final endX = (endLng - longitude) * cosLatitude * 111320;
        final endY = (endLat - latitude) * 111320;
        final segmentX = endX - startX;
        final segmentY = endY - startY;
        final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;
        final projection = segmentLengthSquared == 0
            ? 0.0
            : (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
                  .clamp(0.0, 1.0)
                  .toDouble();
        final distanceX = startX + projection * segmentX;
        final distanceY = startY + projection * segmentY;
        if (math.sqrt(distanceX * distanceX + distanceY * distanceY) <=
            maxDistanceMeters) {
          return true;
        }
      }
    }
    return false;
  }
}
