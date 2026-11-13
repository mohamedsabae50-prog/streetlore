import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:streetlore/core/services/map_route_service.dart';

void main() {
  test(
    'requests walking geometry from OSRM and converts GeoJSON points',
    () async {
      final origin = const LatLng(30, 31);
      final destination = const LatLng(30.002, 31.002);
      late Uri requestUri;
      final client = MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [31.0, 30.0],
                    [31.001, 30.001],
                    [31.002, 30.002],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final service = MapRouteService(client: client);

      final route = await service.getWalkingRoute(origin, destination);

      expect(requestUri.path, contains('/route/v1/foot/'));
      expect(requestUri.queryParameters, {
        'overview': 'full',
        'geometries': 'geojson',
      });
      expect(route.first, origin);
      expect(route.last, destination);
      expect(route, hasLength(3));
      client.close();
    },
  );

  test(
    'falls back to an offline multi-point route when OSRM is unavailable',
    () async {
      final origin = const LatLng(30, 31);
      final destination = const LatLng(30.01, 31.01);
      final client = MockClient((_) async => http.Response('unavailable', 503));
      final service = MapRouteService(client: client);

      final route = await service.getWalkingRoute(origin, destination);

      expect(route.length, greaterThan(2));
      expect(route.first, origin);
      expect(route.last, destination);
      client.close();
    },
  );

  test('remaining route distance shrinks as the live location advances', () {
    const route = [
      LatLng(30, 31),
      LatLng(30.005, 31.005),
      LatLng(30.01, 31.01),
    ];
    final initial = MapRouteService.progressAlongRoute(
      route: route,
      currentLocation: route.first,
    );
    final middle = MapRouteService.progressAlongRoute(
      route: route,
      currentLocation: route[1],
      minimumSegmentIndex: initial.nextSegmentIndex,
    );
    final nearDestination = MapRouteService.progressAlongRoute(
      route: route,
      currentLocation: const LatLng(30.009, 31.009),
      minimumSegmentIndex: middle.nextSegmentIndex,
    );

    expect(
      middle.remainingDistanceMeters,
      lessThan(initial.remainingDistanceMeters),
    );
    expect(
      nearDestination.remainingDistanceMeters,
      lessThan(middle.remainingDistanceMeters),
    );
    expect(
      nearDestination.nextSegmentIndex,
      greaterThanOrEqualTo(middle.nextSegmentIndex),
    );
    expect(
      MapRouteService.walkingMinutes(nearDestination.remainingDistanceMeters),
      2,
    );
  });
}
