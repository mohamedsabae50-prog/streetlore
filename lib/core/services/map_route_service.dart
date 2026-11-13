import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/map_poi.dart';
import '../../data/models/place_model.dart';

typedef WalkingRouteFetcher =
    Future<List<LatLng>> Function(LatLng origin, LatLng destination);

class MapRouteDestination {
  const MapRouteDestination({
    required this.id,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    this.nameAr,
  });

  factory MapRouteDestination.fromPlace(PlaceModel place) =>
      MapRouteDestination(
        id: place.id,
        nameEn: place.nameEn,
        nameAr: place.nameAr,
        latitude: place.lat,
        longitude: place.lng,
      );

  factory MapRouteDestination.fromAtm(MapPoi atm) => MapRouteDestination(
    id: atm.id,
    nameEn: atm.name,
    latitude: atm.lat,
    longitude: atm.lng,
  );

  final String id;
  final String nameEn;
  final String? nameAr;
  final double latitude;
  final double longitude;

  String localizedName(String locale) =>
      locale == 'ar' && nameAr != null && nameAr!.isNotEmpty ? nameAr! : nameEn;

  LatLng get point => LatLng(latitude, longitude);
}

class MapRouteProgress {
  const MapRouteProgress({
    required this.points,
    required this.nextSegmentIndex,
    required this.remainingDistanceMeters,
  });

  final List<LatLng> points;
  final int nextSegmentIndex;
  final double remainingDistanceMeters;
}

class MapRouteService {
  MapRouteService({http.Client? client, this.routeFetcher})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final WalkingRouteFetcher? routeFetcher;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<List<LatLng>> getWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final points = routeFetcher == null
          ? await _fetchOsrmRoute(origin, destination)
          : await routeFetcher!(origin, destination);
      if (points.length < 2) {
        throw const FormatException(
          'Walking route contained fewer than two points.',
        );
      }
      return _includeEndpoints(points, origin, destination);
    } catch (error, stackTrace) {
      debugPrint('MapRouteService: using offline route after failure: $error');
      debugPrint('$stackTrace');
      return buildOfflineFallbackRoute(origin, destination);
    }
  }

  Future<List<LatLng>> _fetchOsrmRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final path =
        '/route/v1/foot/${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.https('router.project-osrm.org', path, {
      'overview': 'full',
      'geometries': 'geojson',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'OSRM returned HTTP ${response.statusCode}.',
        uri,
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['routes'] is! List) {
      throw const FormatException('OSRM response did not contain routes.');
    }
    final routes = payload['routes'] as List;
    if (routes.isEmpty || routes.first is! Map) {
      throw const FormatException('OSRM returned no walking route.');
    }
    final geometry = (routes.first as Map)['geometry'];
    if (geometry is! Map || geometry['coordinates'] is! List) {
      throw const FormatException('OSRM route geometry was invalid.');
    }
    return (geometry['coordinates'] as List)
        .map((coordinate) {
          if (coordinate is! List ||
              coordinate.length < 2 ||
              coordinate[0] is! num ||
              coordinate[1] is! num) {
            throw const FormatException(
              'OSRM route contained invalid coordinates.',
            );
          }
          return LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          );
        })
        .toList(growable: false);
  }

  static List<LatLng> _includeEndpoints(
    List<LatLng> points,
    LatLng origin,
    LatLng destination,
  ) {
    final result = List<LatLng>.of(points);
    if (_distanceMeters(result.first, origin) > 2) {
      result.insert(0, origin);
    } else {
      result[0] = origin;
    }
    if (_distanceMeters(result.last, destination) > 2) {
      result.add(destination);
    } else {
      result[result.length - 1] = destination;
    }
    return List.unmodifiable(result);
  }

  static List<LatLng> buildOfflineFallbackRoute(
    LatLng origin,
    LatLng destination,
  ) {
    if (_distanceMeters(origin, destination) < 1) {
      return List.unmodifiable([origin, destination]);
    }
    const metersPerDegree = 111320.0;
    final midLatitude = (origin.latitude + destination.latitude) / 2;
    final longitudeScale = math.cos(midLatitude * math.pi / 180).abs();
    final dx =
        (destination.longitude - origin.longitude) *
        metersPerDegree *
        longitudeScale;
    final dy = (destination.latitude - origin.latitude) * metersPerDegree;
    final length = math.sqrt(dx * dx + dy * dy);
    final offsetMeters = math.min(45.0, length * 0.08);
    final offsetLat = dx / length * offsetMeters / metersPerDegree;
    final offsetLng =
        -dy /
        length *
        offsetMeters /
        (metersPerDegree * math.max(longitudeScale, 0.01));

    final points = <LatLng>[];
    for (var index = 0; index <= 5; index++) {
      final progress = index / 5;
      final curve = math.sin(math.pi * progress);
      points.add(
        LatLng(
          origin.latitude +
              (destination.latitude - origin.latitude) * progress +
              offsetLat * curve,
          origin.longitude +
              (destination.longitude - origin.longitude) * progress +
              offsetLng * curve,
        ),
      );
    }
    points[0] = origin;
    points[points.length - 1] = destination;
    return List.unmodifiable(points);
  }

  static MapRouteProgress progressAlongRoute({
    required List<LatLng> route,
    required LatLng currentLocation,
    int minimumSegmentIndex = 0,
  }) {
    if (route.length < 2) {
      return MapRouteProgress(
        points: List.unmodifiable([currentLocation]),
        nextSegmentIndex: 0,
        remainingDistanceMeters: 0,
      );
    }

    final startIndex = minimumSegmentIndex.clamp(0, route.length - 2);
    var closestSegment = startIndex;
    var closestPoint = route[startIndex];
    var closestDistance = double.infinity;
    const metersPerDegree = 111320.0;
    final longitudeScale = math.cos(currentLocation.latitude * math.pi / 180);

    for (var index = startIndex; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final ax =
          (start.longitude - currentLocation.longitude) *
          metersPerDegree *
          longitudeScale;
      final ay = (start.latitude - currentLocation.latitude) * metersPerDegree;
      final bx =
          (end.longitude - currentLocation.longitude) *
          metersPerDegree *
          longitudeScale;
      final by = (end.latitude - currentLocation.latitude) * metersPerDegree;
      final dx = bx - ax;
      final dy = by - ay;
      final segmentLengthSquared = dx * dx + dy * dy;
      final fraction = segmentLengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / segmentLengthSquared).clamp(0.0, 1.0);
      final projected = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
      final distance = _distanceMeters(currentLocation, projected);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestSegment = index;
        closestPoint = projected;
      }
    }

    final remaining = <LatLng>[currentLocation];
    if (_distanceMeters(currentLocation, closestPoint) > 2) {
      remaining.add(closestPoint);
    }
    for (final point in route.skip(closestSegment + 1)) {
      if (_distanceMeters(remaining.last, point) > 0.5) remaining.add(point);
    }
    if (remaining.length == 1) remaining.add(route.last);
    final distance = _sumDistance(remaining);
    return MapRouteProgress(
      points: List.unmodifiable(remaining),
      nextSegmentIndex: closestSegment,
      remainingDistanceMeters: distance,
    );
  }

  static double _sumDistance(List<LatLng> points) {
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      total += _distanceMeters(points[index - 1], points[index]);
    }
    return total;
  }

  static double distanceMeters(LatLng first, LatLng second) =>
      _distanceMeters(first, second);

  static double _distanceMeters(LatLng first, LatLng second) {
    const earthRadius = 6371000.0;
    final lat1 = first.latitude * math.pi / 180;
    final lat2 = second.latitude * math.pi / 180;
    final deltaLat = (second.latitude - first.latitude) * math.pi / 180;
    final deltaLng = (second.longitude - first.longitude) * math.pi / 180;
    final haversine =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return 2 *
        earthRadius *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  static String formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  static int walkingMinutes(double meters) =>
      meters <= 0 ? 0 : (meters / 80).ceil();
}
