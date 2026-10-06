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

/// v1.0.80 — VISIBLE error tile (semi-opaque magenta). A failed
/// tile now shows as a small magenta square instead of invisibly
/// vanishing. The bytes below are a hand-built minimal 1×1 PNG
/// (8-bit RGBA, magenta, deflate via zlib).
final Uint8List _kDebugErrorPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0x99, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x9F, 0x01, 0x00, 0x07, 0x82, 0x02, 0x7E, 0xA6,
  0xDC, 0xD2, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// v1.0.86 — Alexandria fallback used for every map computation when
/// Geolocator has not resolved a fix yet. NO nullable variable should
/// ever reach `MapOptions` or any drawing method; we always substitute
/// this concrete LatLng before anything touches the flutter_map API.
const LatLng _kFallbackLoc = LatLng(31.2001, 29.9187); // Alexandria

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
  List<LatLng> _routePoints = const [];
  String _firstTileError = '';

  StreamSubscription<Position>? _positionSub;
  final MapController _mapController = MapController();

  // Last fetched route origin so we can decide whether the user has moved
  // far enough to justify a new OSRM request.
  LatLng? _lastRouteOrigin;

  /// v1.0.87 — Effective waypoints. Always returns at least one item.
  /// Uses null-aware `?.` access exclusively — no `!` operators.
  List<PlaceWaypoint> get _effectiveWaypoints {
    final wp = widget.waypoints;
    if (wp != null && wp.isNotEmpty) return wp;
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
    // v1.0.84 — render the map IMMEDIATELY. GPS fetch happens in the
    // background. When/if it succeeds, setState updates the user
    // marker and centers the map. If GPS fails (timeout, denied, no
    // service), it doesn't matter because the map is already visible
    // and interactive.
    _initLocationInBackground();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocationInBackground() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      if (!mounted) return;
      final newLoc = LatLng(position.latitude, position.longitude);
      _currentLocation = newLoc;
      _lastRouteOrigin = newLoc;
      setState(() {});
      // Fire-and-forget the route + center updates.
      unawaited(_getRoute());
      _centerOnUser(force: true);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPositionUpdate);
    } catch (_) {
      // Silently fail — the map is already rendered with fallback
      // center. Don't surface anything as an error since the user can
      // still see and interact with the map.
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
    _centerOnUser();
  }

  void _centerOnUser({bool force = false}) {
    final loc = _currentLocation;
    if (loc == null) return;
    try {
      _mapController.move(loc, _mapController.camera.zoom);
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

  /// v1.0.87 — Deep-audited route fetch. Returns early and silently
  /// if `_currentLocation` is null. Uses `as num` (NOT `as double`) for
  /// OSRM coordinate parsing because OSRM occasionally emits integers
  /// for whole-number values, and a strict `as double` cast would throw
  /// a TypeError. Every nullable step in the parse chain is guarded
  /// with null-aware access (`?.`) so a malformed OSRM response can
  /// never escape into the UI.
  Future<void> _getRoute() async {
    final loc = _currentLocation;
    final waypoints = _effectiveWaypoints;

    // v1.0.87 — per user directive: if no user location, do NOT draw
    // a route at all (previously we drew a straight-line through the
    // waypoints). The destination pin still shows; user can re-tap
    // 'Go' once GPS is available.
    if (loc == null) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
      return;
    }

    // OSRM URL: /route/v1/driving/lng,lat;lng,lat;...?geometries=geojson
    // We need (start=user) → waypoint1 → waypoint2 → … → waypointN.
    // Cap at _osrmMaxWaypoints waypoints (OSRM limits free tier to ~25).
    final coords = <String>[];
    coords.add('${loc.longitude},${loc.latitude}');
    for (final w in waypoints) {
      if (coords.length >= _osrmMaxWaypoints) break;
      coords.add('${w.lng},${w.lat}');
    }
    if (coords.length < 2) {
      if (!mounted) return;
      setState(() => _routePoints = const []);
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
      if (response.statusCode != 200) return;

      final raw = json.decode(response.body);
      if (raw is! Map) return;
      final routes = raw['routes'];
      if (routes is! List || routes.isEmpty) return;

      final first = routes.first;
      if (first is! Map) return;
      final geometry = first['geometry'];
      if (geometry is! Map) return;
      final coordsJson = geometry['coordinates'];
      if (coordsJson is! List) return;

      final parsed = <LatLng>[];
      for (final c in coordsJson) {
        if (c is! List || c.length < 2) continue;
        final lngNum = c[0];
        final latNum = c[1];
        if (lngNum is! num || latNum is! num) continue;
        final lng = lngNum.toDouble();
        final lat = latNum.toDouble();
        if (!lat.isFinite || !lng.isFinite) continue;
        // Bounding-box sanity check — reject anything outside a
        // generous global range so a corrupt entry can't crash the
        // tile projection math downstream.
        if (lat.abs() > 90 || lng.abs() > 180) continue;
        parsed.add(LatLng(lat, lng));
      }

      if (!mounted) return;
      setState(() => _routePoints = parsed);
    } catch (_) {
      // Silently ignore route failures — destination pin still shows
      // on the map. Per v1.0.87 directive: never draw a partial route.
      if (!mounted) return;
      setState(() => _routePoints = const []);
    }
  }

  /// v1.0.87 — Returns `_routePoints` filtered to finite coords only.
  /// The map should never receive a non-finite LatLng, and a single bad
  /// entry could crash flutter_map's projection math.
  List<LatLng> get _safeRoutePoints => _routePoints
      .where((p) =>
          p.latitude.isFinite &&
          p.longitude.isFinite &&
          p.latitude.abs() <= 90 &&
          p.longitude.abs() <= 180)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    // v1.0.78: bulletproof ESRI World Street Map (no rate limit, no
    // user-agent block). Note ESRI uses {z}/{y}/{x} order (not {x}/{y}),
    // and the server is a single canonical host with no subdomains. We
    // keep CartoDB and OSM as fallbacks in case ESRI is ever down.
    // v1.0.80 — CartoDB Voyager primary (no rate-limit, works in Egypt),
    // OSM + ESRI as 2-tier fallbacks. NOTE: the empty subdomain '' that
    // v1.0.78 used to "support" ESRI (which has no {s} placeholder) broke
    // CartoDB and OSM — their {s}.basemaps.cartocdn.com fallback URLs got
    // rewritten to "https://.basemaps.cartocdn.com/..." which is an invalid
    // host. With no valid fallback, when ESRI was blocked we fell back to
    // a fully-broken URL set and the user saw a solid gray map. We now
    // keep subdomains = ['a','b','c'] (CartoDB + OSM only) and rely on
    // the tile ordering to pick ESRI when neither CartoDB nor OSM
    // responds.
    const List<String> tileUrls = [
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    ];
    const List<String> tileSubdomains = ['a', 'b', 'c'];

    // v1.0.86 — hard-loc `userLoc` (with Alexandria fallback) so nothing
    // nullable ever reaches MapOptions or any drawing method. `hasUserLoc`
    // gates the user-marker rendering (we don't draw a fake blue dot when
    // GPS hasn't resolved yet — only show the destination pin).
    final LatLng userLoc = _currentLocation ?? _kFallbackLoc;
    final bool hasUserLoc = _currentLocation != null;
    final waypoints = _effectiveWaypoints;
    final safeRoute = _safeRoutePoints;

    // v1.0.87 — pick the initial center with destination as primary,
    // user loc as secondary, Alexandria as ultimate fallback. Each
    // candidate is checked for finiteness so a corrupt CoordinateRef
    // can never reach MapOptions.
    final LatLng initialCenter = (() {
      final wp0 = waypoints.isNotEmpty ? waypoints.first : null;
      if (wp0 != null && wp0.lat.isFinite && wp0.lng.isFinite) {
        return LatLng(wp0.lat, wp0.lng);
      }
      if (userLoc.latitude.isFinite && userLoc.longitude.isFinite) {
        return userLoc;
      }
      return _kFallbackLoc;
    })();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeName),
        centerTitle: true,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: waypoints.length > 1 ? 12.0 : 14.0,
          minZoom: 3.0,
          maxZoom: 18.0,
          onMapReady: () {
            if (waypoints.length > 1 && safeRoute.length >= 2) {
              _fitToRoute();
            } else if (hasUserLoc) {
              _centerOnUser(force: true);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrls.first,
            fallbackUrl: tileUrls.length > 1
                ? tileUrls.sublist(1).join('||')
                : null,
            userAgentPackageName: 'com.streetlore.app',
            subdomains: tileSubdomains,
            keepBuffer: 8,
            maxNativeZoom: 19,
            tileProvider: NetworkTileProvider(),
            errorTileCallback: (tile, error, stackTrace) {
              final msg = 'tile failed: $error';
              debugPrint('MapScreen $msg');
              if (mounted && _firstTileError.isEmpty) {
                _firstTileError = msg;
                setState(() {});
              }
            },
            errorImage: MemoryImage(_kDebugErrorPng),
          ),

          // v1.0.87 — polyline only renders if we have >= 2 finite,
          // bounding-box-valid points. Anything shorter would crash
          // flutter_map's projection math on a singleton line.
          if (safeRoute.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: safeRoute,
                  color: Colors.blueAccent,
                  strokeWidth: 5.0,
                ),
              ],
            ),

          // Stop markers — only show as numbered pins in tour mode so
          // the user can see the sequence. In single-destination mode
          // the destination still uses the classic red pin.
          MarkerLayer(
            markers: [
              // v1.0.87 — user marker only renders when GPS resolved.
              if (hasUserLoc)
                Marker(
                  point: userLoc,
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

          // v1.0.80 — visible error banner so a half-elsewhere gray map is
          // immediately debuggable. Shows the first tile-failure
          // message. Dismissable.
          if (_firstTileError.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: const Color(0xCC7F1D1D),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Map tiles failed: $_firstTileError',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                        onPressed: () => setState(() {
                          _firstTileError = '';
                        }),
                      ),
                    ],
                  ),
                ),
              ),
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
    );
  }

  void _fitToRoute() {
    if (_routePoints.length < 2) return;
    final bounds = LatLngBounds.fromPoints(_safeRoutePoints);
    if (bounds.southWest.latitude.isNaN ||
        bounds.northEast.latitude.isNaN) {
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (_) {
      // CameraFit.bounds can throw if the bounds are degenerate.
      // Swallow silently; user can re-center manually.
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