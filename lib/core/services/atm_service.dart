import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/models/map_poi.dart';

class AtmService {
  AtmService._();

  static const _alexandriaLandBoundary = <List<double>>[
    [31.04, 29.82],
    [31.17, 29.82],
    [31.205, 29.86],
    [31.235, 29.89],
    [31.252, 29.92],
    [31.265, 29.95],
    [31.278, 29.98],
    [31.298, 30.015],
    [31.303, 30.06],
    [31.22, 30.15],
    [31.06, 30.12],
  ];

  static const alexandriaAtms = <MapPoi>[
    MapPoi(
      id: 'atm-nbe-talaat-harb-raml',
      name: 'National Bank of Egypt (NBE) - Talaat Harb / Raml',
      address: 'Talaat Harb St, Raml Station',
      lat: 31.1994,
      lng: 29.9018,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-banque-misr-talaat-harb',
      name: 'Banque Misr - Talaat Harb Main Branch',
      address: 'Talaat Harb St, Raml Station',
      lat: 31.1991,
      lng: 29.9024,
      category: 'atm',
      brand: 'Banque Misr',
      icon: Icons.atm_rounded,
      color: Color(0xFF1F4E79),
    ),
    MapPoi(
      id: 'atm-cib-saad-zaghloul-raml',
      name: 'CIB - Saad Zaghloul / Raml Station',
      address: 'Saad Zaghloul St, Raml Station',
      lat: 31.2012,
      lng: 29.9006,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-alexbank-saad-zaghloul',
      name: 'AlexBank - Saad Zaghloul St',
      address: 'Saad Zaghloul St, Raml Station',
      lat: 31.2008,
      lng: 29.9014,
      category: 'atm',
      brand: 'AlexBank',
      icon: Icons.atm_rounded,
      color: Color(0xFFB22222),
    ),
    MapPoi(
      id: 'atm-qnb-fouad',
      name: 'QNB Alahli - Fouad St (Horreya Rd)',
      address: 'Fouad St (Horreya Rd), Raml Station',
      lat: 31.1982,
      lng: 29.9065,
      category: 'atm',
      brand: 'QNB Alahli',
      icon: Icons.atm_rounded,
      color: Color(0xFF8B1A1A),
    ),
    MapPoi(
      id: 'atm-nbe-fouad',
      name: 'National Bank of Egypt (NBE) - Fouad St',
      address: 'Fouad St, Raml Station',
      lat: 31.1976,
      lng: 29.9082,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-banque-caire-salah-salem',
      name: 'Banque du Caire - Salah Salem St (Attarine)',
      address: 'Salah Salem St, Attarine',
      lat: 31.1986,
      lng: 29.8975,
      category: 'atm',
      brand: 'Banque du Caire',
      icon: Icons.atm_rounded,
      color: Color(0xFF15803D),
    ),
    MapPoi(
      id: 'atm-nbe-mansheya',
      name: 'NBE - Mansheya Square (Tahrir Sq)',
      address: 'Mansheya Square (Tahrir Sq)',
      lat: 31.2003,
      lng: 29.8942,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-banque-misr-bahary',
      name: 'Banque Misr - Bahary (Qasr Ras El-Tin St)',
      address: 'Qasr Ras El-Tin St, Bahary',
      lat: 31.2095,
      lng: 29.8824,
      category: 'atm',
      brand: 'Banque Misr',
      icon: Icons.atm_rounded,
      color: Color(0xFF1F4E79),
    ),
    MapPoi(
      id: 'atm-cib-sultan-hussein',
      name: 'CIB - Sultan Hussein St (Azarita)',
      address: 'Sultan Hussein St, Azarita',
      lat: 31.2028,
      lng: 29.9108,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-nbe-shatby',
      name: 'NBE - Shatby (Port Said St)',
      address: 'Port Said St, Shatby',
      lat: 31.2092,
      lng: 29.9168,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-qnb-camp-caesar',
      name: 'QNB Alahli - Camp Caesar (Port Said St)',
      address: 'Port Said St, Camp Caesar',
      lat: 31.2136,
      lng: 29.9218,
      category: 'atm',
      brand: 'QNB Alahli',
      icon: Icons.atm_rounded,
      color: Color(0xFF8B1A1A),
    ),
    MapPoi(
      id: 'atm-cib-ibrahimia',
      name: 'CIB - Ibrahimia (Horreya Rd)',
      address: 'Horreya Rd, Ibrahimia',
      lat: 31.2148,
      lng: 29.9275,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-banque-misr-sporting',
      name: 'Banque Misr - Sporting (Horreya Rd)',
      address: 'Horreya Rd, Sporting',
      lat: 31.2188,
      lng: 29.9345,
      category: 'atm',
      brand: 'Banque Misr',
      icon: Icons.atm_rounded,
      color: Color(0xFF1F4E79),
    ),
    MapPoi(
      id: 'atm-nbe-cleopatra',
      name: 'NBE - Cleopatra (Port Said St)',
      address: 'Port Said St, Cleopatra',
      lat: 31.2225,
      lng: 29.9368,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-cib-sidi-gaber',
      name: 'CIB - Sidi Gaber (Syria St / Horreya Rd)',
      address: 'Syria St / Horreya Rd, Sidi Gaber',
      lat: 31.2216,
      lng: 29.9432,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-qnb-syria-roushdy',
      name: 'QNB Alahli - Syria St (Roushdy)',
      address: 'Syria St, Roushdy',
      lat: 31.2268,
      lng: 29.9458,
      category: 'atm',
      brand: 'QNB Alahli',
      icon: Icons.atm_rounded,
      color: Color(0xFF8B1A1A),
    ),
    MapPoi(
      id: 'atm-hsbc-kafr-abdo',
      name: 'HSBC - Kafr Abdo (Saint Ginny St)',
      address: 'Saint Ginny St, Kafr Abdo',
      lat: 31.2222,
      lng: 29.9515,
      category: 'atm',
      brand: 'HSBC',
      icon: Icons.atm_rounded,
      color: Color(0xFFDB0011),
    ),
    MapPoi(
      id: 'atm-cib-smouha-victor-emmanuel',
      name: 'CIB - Smouha (Victor Emmanuel Sq)',
      address: 'Victor Emmanuel Sq, Smouha',
      lat: 31.2145,
      lng: 29.9448,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-nbe-smouha-club',
      name: 'NBE - Smouha Club Gate (14 May Bridge Rd)',
      address: '14 May Bridge Rd, Smouha',
      lat: 31.2168,
      lng: 29.9486,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-alexbank-stanley',
      name: 'AlexBank - Stanley (Abdel Salam Aref St)',
      address: 'Abdel Salam Aref St, Stanley',
      lat: 31.2335,
      lng: 29.9522,
      category: 'atm',
      brand: 'AlexBank',
      icon: Icons.atm_rounded,
      color: Color(0xFFB22222),
    ),
    MapPoi(
      id: 'atm-banque-misr-gleem',
      name: 'Banque Misr - Gleem (Abdel Salam Aref St)',
      address: 'Abdel Salam Aref St, Gleem',
      lat: 31.2392,
      lng: 29.9612,
      category: 'atm',
      brand: 'Banque Misr',
      icon: Icons.atm_rounded,
      color: Color(0xFF1F4E79),
    ),
    MapPoi(
      id: 'atm-cib-san-stefano',
      name: 'CIB - San Stefano Grand Plaza',
      address: 'San Stefano Grand Plaza',
      lat: 31.2450,
      lng: 29.9662,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-nbe-louran',
      name: 'NBE - Louran (Shaarawy St)',
      address: 'Shaarawy St, Louran',
      lat: 31.2482,
      lng: 29.9745,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
    MapPoi(
      id: 'atm-banque-misr-sidi-bishr',
      name:
          'Banque Misr - Sidi Bishr Bahary (Khaled Ibn El-Walid / Gamal Abdel Nasser)',
      address: 'Khaled Ibn El-Walid / Gamal Abdel Nasser, Sidi Bishr Bahary',
      lat: 31.2588,
      lng: 29.9885,
      category: 'atm',
      brand: 'Banque Misr',
      icon: Icons.atm_rounded,
      color: Color(0xFF1F4E79),
    ),
    MapPoi(
      id: 'atm-cib-asafra-mandara',
      name: 'CIB - Asafra / Mandara (Gamal Abdel Nasser St)',
      address: 'Gamal Abdel Nasser St, Asafra / Mandara',
      lat: 31.2715,
      lng: 30.0045,
      category: 'atm',
      brand: 'CIB',
      icon: Icons.atm_rounded,
      color: Color(0xFFED1C24),
    ),
    MapPoi(
      id: 'atm-nbe-montaza-sheraton',
      name: 'NBE - Montaza / Sheraton Gate',
      address: 'Montaza / Sheraton Gate',
      lat: 31.2818,
      lng: 30.0165,
      category: 'atm',
      brand: 'NBE',
      icon: Icons.atm_rounded,
      color: Color(0xFF0033A0),
    ),
  ];

  static List<MapPoi> get curatedAlexandriaAtms => alexandriaAtms
      .where((atm) => isOnAlexandriaLand(atm.lat, atm.lng))
      .toList(growable: false);

  static Future<List<MapPoi>> fetchNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 2500,
    http.Client? client,
  }) async {
    final fallbackAtms = curatedAlexandriaAtms;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radiusMeters <= 0) {
      return fallbackAtms;
    }
    try {
      final query =
          '[out:json][timeout:3];node["amenity"="atm"]'
          '(around:$radiusMeters,$latitude,$longitude);out body;';
      final uri = Uri.https('overpass-api.de', '/api/interpreter', {
        'data': query,
      });
      final request = client?.get ?? http.get;
      final response = await request(
        uri,
        headers: const {'User-Agent': 'StreetLore/2.1.25 (Alexandria guide)'},
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return fallbackAtms;
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['elements'] is! List) {
        return fallbackAtms;
      }

      const brandColors = <String, Color>{
        'cib': Color(0xFFED1C24),
        'nbe': Color(0xFF0033A0),
        'qnb': Color(0xFF8B1A1A),
        'banque misr': Color(0xFF1F4E79),
        'alex bank': Color(0xFFB22222),
        'alexbank': Color(0xFFB22222),
        'hsbc': Color(0xFFDB0011),
        'banque du caire': Color(0xFF15803D),
      };
      final atms = <MapPoi>[];
      for (final element in payload['elements'] as List) {
        if (element is! Map ||
            element['type'] != 'node' ||
            element['lat'] is! num ||
            element['lon'] is! num ||
            element['tags'] is! Map) {
          continue;
        }
        final lat = (element['lat'] as num).toDouble();
        final lng = (element['lon'] as num).toDouble();
        if (!isOnAlexandriaLand(lat, lng)) continue;

        final tags = element['tags'] as Map;
        final brand = (tags['brand'] ?? tags['operator'])?.toString();
        final name = (tags['name'] ?? brand ?? 'ATM').toString().trim();
        final street = tags['addr:street']?.toString().trim() ?? '';
        final houseNumber = tags['addr:housenumber']?.toString().trim() ?? '';
        final address = [
          if (houseNumber.isNotEmpty) houseNumber,
          if (street.isNotEmpty) street,
        ].join(' ');
        final brandKey = brand?.toLowerCase() ?? '';
        var color = const Color(0xFF15803D);
        for (final entry in brandColors.entries) {
          if (brandKey.contains(entry.key)) {
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

      final mergedAtms = [...fallbackAtms];
      for (final candidate in atms) {
        final duplicate = mergedAtms.any(
          (existing) =>
              (existing.lat - candidate.lat).abs() < 0.0003 &&
              (existing.lng - candidate.lng).abs() < 0.0003,
        );
        if (!duplicate) mergedAtms.add(candidate);
      }
      return mergedAtms;
    } catch (_) {
      return fallbackAtms;
    }
  }

  static bool isOnAlexandriaLand(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 31.04 ||
        latitude > 31.303 ||
        longitude < 29.82 ||
        longitude > 30.15) {
      return false;
    }

    var inside = false;
    for (
      var current = 0, previous = _alexandriaLandBoundary.length - 1;
      current < _alexandriaLandBoundary.length;
      previous = current++
    ) {
      final currentPoint = _alexandriaLandBoundary[current];
      final previousPoint = _alexandriaLandBoundary[previous];
      final currentLat = currentPoint[0];
      final currentLng = currentPoint[1];
      final previousLat = previousPoint[0];
      final previousLng = previousPoint[1];
      final crossesLatitude =
          (currentLat > latitude) != (previousLat > latitude);
      if (crossesLatitude &&
          longitude <
              (previousLng - currentLng) *
                      (latitude - currentLat) /
                      (previousLat - currentLat) +
                  currentLng) {
        inside = !inside;
      }
    }
    return inside;
  }
}
