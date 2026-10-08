import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';

final Uint8List _kTransparentPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class PlaceWaypoint {
  final double lat;
  final double lng;
  final String name;
  const PlaceWaypoint({
    required this.lat,
    required this.lng,
    required this.name,
  });
}

class MapScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String placeName;

  final List<PlaceWaypoint>? waypoints;

  const MapScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.placeName,
    this.waypoints,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _reRouteMeters = 50.0;
  static const int _osrmMaxWaypoints = 25;

  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  String _errorMessage = '';

  StreamSubscription<Position>? _positionSub;
  final MapController _mapController = MapController();

  LatLng? _lastRouteOrigin;

  List<PlaceWaypoint> get _effectiveWaypoints {
    final w = widget.waypoints;
    if (w != null && w.isNotEmpty) {
      return w;
    }
    return [
      PlaceWaypoint(
        lat: widget.destinationLat,
        lng: widget.destinationLng,
        name: widget.placeName,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final serviceOn = await Geolocator.isLocationServiceEnabled();
        if (serviceOn) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          if (mounted) {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _lastRouteOrigin = _currentLocation;

            _positionSub = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10,
              ),
            ).listen(_onPositionUpdate);
          }
        } else {
          _errorMessage = context.tr('map_err_location');
        }
      } else {
        _errorMessage = context.tr('map_err_location_denied');
      }
    } catch (e) {
      _errorMessage = context.tr('map_err_location');
    }

    if (!mounted) return;

    await _getRoute();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final newLoc = LatLng(position.latitude, position.longitude);
    setState(() => _currentLocation = newLoc);

    final lastOrigin = _lastRouteOrigin;
    final driftedMeters = lastOrigin == null
        ? double.infinity
        : _distanceMeters(lastOrigin, newLoc);
    if (driftedMeters >= _reRouteMeters) {
      _lastRouteOrigin = newLoc;
      _getRoute();
    }
  }

  void _centerOnUser({bool force = false}) {
    if (_currentLocation == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_currentLocation!, _mapController.camera.zoom);
      } catch (_) {}
    });
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  Future<void> _getRoute() async {
    final List<PlaceWaypoint> waypoints = _effectiveWaypoints;
    if (_currentLocation == null && waypoints.isEmpty) return;

    final coords = <String>[];
    if (_currentLocation != null) {
      coords.add(
        '${_currentLocation!.longitude},${_currentLocation!.latitude}',
      );
    }

    for (var i = 0; i < waypoints.length; i++) {
      final w = waypoints[i];
      if (coords.length >= _osrmMaxWaypoints) break;
      coords.add('${w.lng},${w.lat}');
    }

    if (coords.length < 2) {
      if (!mounted) return;
      setState(() {
        final List<LatLng> fallbackRoute = [];
        for (var i = 0; i < waypoints.length; i++) {
          fallbackRoute.add(LatLng(waypoints[i].lat, waypoints[i].lng));
        }
        _routePoints = fallbackRoute;
      });
      return;
    }

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${coords.join(';')}?geometries=geojson&overview=full',
    );

    try {
      final response = await http
          .get(url, headers: const {'User-Agent': 'com.streetlore.app/1.0'})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded != null && decoded is Map) {
          final dynamic routesList = decoded['routes'];
          if (routesList != null &&
              routesList is List &&
              routesList.isNotEmpty) {
            final dynamic firstRoute = routesList[0];
            if (firstRoute != null && firstRoute is Map) {
              final dynamic geometry = firstRoute['geometry'];
              if (geometry != null && geometry is Map) {
                final dynamic coordinates = geometry['coordinates'];
                if (coordinates != null && coordinates is List) {
                  final List<LatLng> newRoutePoints = [];
                  for (var i = 0; i < coordinates.length; i++) {
                    final dynamic c = coordinates[i];
                    if (c != null && c is List && c.length >= 2) {
                      final dynamic lng = c[0];
                      final dynamic lat = c[1];
                      if (lng is num && lat is num) {
                        newRoutePoints.add(
                          LatLng(lat.toDouble(), lng.toDouble()),
                        );
                      }
                    }
                  }
                  setState(() {
                    _routePoints = newRoutePoints;
                  });
                  return;
                }
              }
            }
          }
        }
        throw Exception('Malformed OSRM response');
      } else {
        throw Exception('API status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OSRM Error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('map_err_route');
        final List<LatLng> fallbackRoute = [];
        for (var i = 0; i < waypoints.length; i++) {
          fallbackRoute.add(LatLng(waypoints[i].lat, waypoints[i].lng));
        }
        _routePoints = fallbackRoute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tileUrls = [
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ];
    final List<String> tileSubdomains = ['', 'a', 'b', 'c', 'd'];
    final List<PlaceWaypoint> waypoints = _effectiveWaypoints;

    final List<Marker> markerList = [];
    if (_currentLocation != null) {
      markerList.add(
        Marker(
          point: _currentLocation!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 14),
          ),
        ),
      );
    }

    if (waypoints.length > 1) {
      for (var i = 0; i < waypoints.length; i++) {
        markerList.add(
          Marker(
            point: LatLng(waypoints[i].lat, waypoints[i].lng),
            width: 40,
            height: 40,
            child: _NumberedPin(
              index: i + 1,
              total: waypoints.length,
              isLast: i == waypoints.length - 1,
            ),
          ),
        );
      }
    } else if (waypoints.isNotEmpty) {
      markerList.add(
        Marker(
          point: LatLng(waypoints[0].lat, waypoints[0].lng),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    final List<Widget> mapChildren = [];
    mapChildren.add(
      TileLayer(
        urlTemplate: tileUrls[0],
        fallbackUrl: tileUrls.length > 1
            ? tileUrls.sublist(1).join('||')
            : null,
        userAgentPackageName: 'com.streetlore.app',
        subdomains: tileSubdomains,
        keepBuffer: 8,
        maxNativeZoom: 19,
        tileProvider: NetworkTileProvider(),
        errorTileCallback: (tile, error, stackTrace) {
          debugPrint('MapScreen tile ERROR: $error');
        },
        errorImage: MemoryImage(_kTransparentPng),
      ),
    );

    if (_routePoints.isNotEmpty && _routePoints.length > 1) {
      mapChildren.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: _routePoints,
              color: Colors.blueAccent,
              strokeWidth: 5.0,
            ),
          ],
        ),
      );
    }

    mapChildren.add(MarkerLayer(markers: markerList));
    return Scaffold(
      appBar: AppBar(title: Text(widget.placeName), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _currentLocation ??
                        (waypoints.isNotEmpty
                            ? LatLng(waypoints[0].lat, waypoints[0].lng)
                            : const LatLng(31.2001, 29.9187)),
                    initialZoom: waypoints.length > 1 ? 12.0 : 14.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onMapReady: () {
                      if (waypoints.length > 1 && _routePoints.length > 1) {
                        _fitToRoute();
                      } else if (_currentLocation != null) {
                        _centerOnUser(force: true);
                      } else if (waypoints.isNotEmpty) {
                        try {
                          _mapController.move(
                            LatLng(waypoints[0].lat, waypoints[0].lng),
                            14.0,
                          );
                        } catch (_) {}
                      }
                    },
                  ),
                  children: mapChildren,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Text(
                      '© OpenStreetMap © CARTO',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _fitToRoute() {
    if (_routePoints.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (e) {
      debugPrint('Fit route error: $e');
    }
  }
}

class _NumberedPin extends StatelessWidget {
  final int index;
  final int total;
  final bool isLast;
  const _NumberedPin({
    required this.index,
    required this.total,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLast ? AppColors.success : AppColors.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.location_on, color: color, size: 40),
        Positioned(
          top: 8,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
