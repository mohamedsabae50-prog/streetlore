import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/egypt_governorate.dart';

class GovernorateService {
  GovernorateService._();

  static List<EgyptGovernorate> get governorates => EgyptGovernorate.all;

  static EgyptGovernorate detectFromCoordinates(double lat, double lng) {
    if (lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90) {
      final alexandria = EgyptGovernorate.byId['alexandria']!;
      if (_containsPoint(alexandria.boundaryPolygon, lat, lng)) {
        return alexandria;
      }
      final matches = governorates.where(
        (governorate) =>
            governorate.id != 'alexandria' &&
            _containsPoint(governorate.boundaryPolygon, lat, lng),
      );
      if (matches.isNotEmpty) {
        return matches.reduce((nearest, candidate) {
          final nearestDistance = _haversineDistance(
            lat,
            lng,
            nearest.centerLat,
            nearest.centerLng,
          );
          final candidateDistance = _haversineDistance(
            lat,
            lng,
            candidate.centerLat,
            candidate.centerLng,
          );
          return candidateDistance < nearestDistance ? candidate : nearest;
        });
      }
    }

    return governorates.reduce((nearest, candidate) {
      final nearestDistance = _haversineDistance(
        lat,
        lng,
        nearest.centerLat,
        nearest.centerLng,
      );
      final candidateDistance = _haversineDistance(
        lat,
        lng,
        candidate.centerLat,
        candidate.centerLng,
      );
      return candidateDistance < nearestDistance ? candidate : nearest;
    });
  }

  static bool _containsPoint(List<LatLng> polygon, double lat, double lng) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final current = polygon[i];
      final previous = polygon[j];
      final crosses =
          (current.latitude > lat) != (previous.latitude > lat) &&
          lng <
              (previous.longitude - current.longitude) *
                      (lat - current.latitude) /
                      (previous.latitude - current.latitude) +
                  current.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final toRadians = math.pi / 180;
    const earthRadiusKm = 6371.0;
    final firstLat = lat1 * toRadians;
    final secondLat = lat2 * toRadians;
    final dLat = (lat2 - lat1) * toRadians;
    final dLng = (lng2 - lng1) * toRadians;
    final haversine =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(firstLat) *
            math.cos(secondLat) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 *
        earthRadiusKm *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}
