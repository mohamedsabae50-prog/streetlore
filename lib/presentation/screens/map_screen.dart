import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';

/// v1.0.78 — 1×1 fully-transparent PNG bytes. Used as the
/// errorImage fallback so a single failed tile doesn't blank the
/// whole map with a solid gray block.
final Uint8List _kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR length+tag
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // 8-bit RGBA
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, // IDAT length+tag
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, // zlib stream
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // (deflate)
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
  0x42, 0x60, 0x82,                                     // CRC
]);

/// One-waypoint mode — pass `destinationLat` + `destinationLng` for the
/// classic "Go to place" navigation.
///
/// Multi-waypoint mode — pass `waypoints` (a list of PlaceWaypoint structs)
/// for the Tour/Trip screen, which draws an OSRM route through every
/// stop sequentially.
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

  /// Optional multi-waypoint tour/trip route. When non-null, takes
  /// precedence over the single-destination fields.
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

  // Last fetched route origin so we can decide whether the user has moved
  // far enough to justify a new OSRM request.
  LatLng? _lastRouteOrigin;

  List<PlaceWaypoint> get _effectiveWaypoints =>
      (widget.waypoints != null && widget.waypoints!.isNotEmpty)
          ? widget.waypoints!
          : [
              PlaceWaypoint(
                lat: widget.destinationLat,
                lng: widget.destinationLng,
                name: widget.placeName,
              ),
            ];

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
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = context.tr('map_err_location_denied');
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = context.tr('map_err_location_denied_forever');
        });
        return;
      }

      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = context.tr('map_err_location');
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      _currentLocation = LatLng(position.latitude, position.longitude);
      _lastRouteOrigin = _currentLocation;

      await _getRoute();
      _centerOnUser(force: true);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPositionUpdate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('map_err_location');
      });
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final newLoc = LatLng(position.latitude, position.longitude);
    setState(() => _currentLocation = newLoc);

    final driftedMeters = _lastRouteOrigin == null
        ? double.infinity
        : _distanceMeters(_lastRouteOrigin!, newLoc);
    if (driftedMeters >= _reRouteMeters) {
      _lastRouteOrigin = newLoc;
      _getRoute();
    }
    _centerOnUser();
  }

  void _centerOnUser({bool force = false}) {
    if (_currentLocation == null) return;
    try {
      _mapController.move(_currentLocation!, _mapController.camera.zoom);
    } catch (_) {
      // camera not ready yet — ignore
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  Future<void> _getRoute() async {
    final waypoints = _effectiveWaypoints;
    if (_currentLocation == null && waypoints.isEmpty) return;

    // OSRM URL: /route/v1/driving/lng,lat;lng,lat;...?geometries=geojson
    // We need (start=user) → waypoint1 → waypoint2 → … → waypointN.
    // Cap at _osrmMaxWaypoints waypoints (OSRM limits free tier to ~25).
    final coords = <String>[];
    if (_currentLocation != null) {
      coords.add(
        '${_currentLocation!.longitude},${_currentLocation!.latitude}',
      );
    }
    for (final w in waypoints) {
      if (coords.length >= _osrmMaxWaypoints) break;
      coords.add('${w.lng},${w.lat}');
    }
    if (coords.length < 2) {
      // No user location and only one destination — straight line.
      if (!mounted) return;
      setState(() {
        _routePoints = waypoints
            .map((w) => LatLng(w.lat, w.lng))
            .toList(growable: false);
        _isLoading = false;
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
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = context.tr('map_err_route');
          });
          return;
        }
        final List<dynamic> coordsJson =
            routes[0]['geometry']['coordinates'] as List<dynamic>;
        setState(() {
          _routePoints = coordsJson
              .map((c) => LatLng(c[1] as double, c[0] as double))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = context.tr('map_err_route');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.tr('map_err_offline');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // v1.0.78: bulletproof ESRI World Street Map (no rate limit, no
// user-agent block). Note ESRI uses {z}/{y}/{x} order (not {x}/{y}),
// and the server is a single canonical host with no subdomains. We
// keep CartoDB and OSM as fallbacks in case ESRI is ever down.
const List<String> _tileUrls = [
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
];
const List<String> _tileSubdomains = ['', 'a', 'b', 'c', 'd'];
    final waypoints = _effectiveWaypoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeName),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _routePoints.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : SizedBox.expand(
                  // v1.0.89 — SizedBox.expand gives FlutterMap explicit
                  // bounded constraints. Without it, FlutterMap inside a
                  // Scaffold body on Flutter Web can report unbounded
                  // height to its children, which throws layout errors
                  // every frame.
                  child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // v1.0.75: pick the best initial center. Previously
                    // when location was denied we fell back to (0, 0)
                    // which renders as a solid-gray open-ocean tile —
                    // giving the impression of a "broken" map. Now we
                    // default to the first waypoint (or destination)
                    // so the user always sees the place they meant to
                    // open.
                    initialCenter: _currentLocation ??
                        (waypoints.isNotEmpty
                            ? LatLng(
                                waypoints.first.lat,
                                waypoints.first.lng,
                              )
                            : const LatLng(31.2001, 29.9187) // Alexandria
                            ),
                    initialZoom: waypoints.length > 1 ? 12.0 : 14.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onMapReady: () {
                      if (waypoints.length > 1 && _routePoints.isNotEmpty) {
                        _fitToRoute();
                      } else if (_currentLocation != null) {
                        _centerOnUser(force: true);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                    // v1.0.78: ESRI + 2-tier fallback. If the primary
                    // host fails, flutter_map walks the list
                    // automatically. We also paint a tiny transparent
                    // PNG as the error tile so a single 404 doesn't
                    // blank the whole map with a solid gray block.
                    urlTemplate: _tileUrls.first,
                    fallbackUrl: _tileUrls.length > 1
                        ? _tileUrls.sublist(1).join('||')
                        : null,
                    userAgentPackageName: 'com.streetlore.app',
                    subdomains: _tileSubdomains,
                    keepBuffer: 8,
                    maxNativeZoom: 19,
                    tileProvider: NetworkTileProvider(),
                    // v1.0.78: surface every failed tile in the console
                    // so a "gray map" is debuggable instead of silent.
                    // The current flutter_map signature is
                    // (TileImage, Object, StackTrace?) — no coords —
                    // so we just log the error itself.
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('MapScreen tile ERROR: $error');
                    },
                    // 1×1 transparent PNG (avoids shipping a binary asset).
                    errorImage: MemoryImage(_kTransparentPng),
                  ),

                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: Colors.blueAccent,
                            strokeWidth: 5.0,
                          ),
                        ],
                      ),

                    // Stop markers — only show as numbered pins in tour
                    // mode so the user can see the sequence. In single-
                    // destination mode the destination still uses the
                    // classic red pin.
                    MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        if (waypoints.length > 1)
                          for (var i = 0; i < waypoints.length; i++)
                            Marker(
                              point: LatLng(
                                waypoints[i].lat,
                                waypoints[i].lng,
                              ),
                              width: 40,
                              height: 40,
                              child: _NumberedPin(
                                index: i + 1,
                                total: waypoints.length,
                                isLast: i == waypoints.length - 1,
                              ),
                            )
                        else
                          Marker(
                            point: LatLng(
                              waypoints.first.lat,
                              waypoints.first.lng,
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                      ],
                    ),

                    // Map data attribution — required by OSM license.
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
                          '© OpenStreetMap · © CARTO',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                ),
    );
  }

  void _fitToRoute() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
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