import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/atm_service.dart';
import '../../core/services/carplay_service.dart';
import '../../core/services/map_route_service.dart';
import '../../data/models/egypt_governorate.dart';
import '../../data/models/map_poi.dart';
import '../../data/models/place_model.dart';
import '../../core/services/offline_tile_provider.dart';
import '../../l10n/app_strings.dart';
import '../../logic/place_provider.dart';
import '../../logic/governorate_provider.dart';
import '../../logic/trip_provider.dart';
import '../widgets/governorate_explorer_sheet.dart';
import '../widgets/governorate_fog_layer.dart';
import '../widgets/governorate_selector.dart';
import '../widgets/map_route_hud.dart';
import '_atm_sheet.dart';
import 'place_details_screen.dart';

String _catLabel(BuildContext context, String cat) {
  switch (cat) {
    case 'All':
      return context.tr('cat_all');
    case 'Historical':
      return context.tr('cat_historical');
    case 'Culture':
      return context.tr('cat_culture');
    case 'Nature':
      return context.tr('cat_nature');
    case 'Food':
      return context.tr('cat_food');
    case 'Cafe':
    case 'Cafes':
      return context.tr('cat_cafes');
    case 'Shopping':
      return context.tr('cat_shopping');
    case 'Mosques':
      return context.tr('cat_mosques');
    case 'Churches':
      return context.tr('cat_churches');
    case 'Hotels':
      return context.tr('cat_hotels');
    default:
      return cat;
  }
}

String _normalizeMapCategory(String category) {
  switch (category.trim().toLowerCase()) {
    case 'cafe':
    case 'cafes':
      return 'cafes';
    case 'mosque':
    case 'mosques':
      return 'mosques';
    case 'church':
    case 'churches':
      return 'churches';
    case 'hotel':
    case 'hotels':
      return 'hotels';
    case 'museum':
    case 'museums':
    case 'culture':
      return 'culture';
    case 'park':
    case 'parks':
    case 'nature':
      return 'nature';
    case 'atm':
    case 'atms':
      return 'atms';
    default:
      return category.trim().toLowerCase();
  }
}

List<MapPoi> _mergeAtms(Iterable<MapPoi> candidates) {
  final result = <MapPoi>[];
  for (final candidate in candidates) {
    final duplicate = result.any(
      (existing) =>
          existing.id == candidate.id ||
          ((existing.lat - candidate.lat).abs() < 0.0003 &&
              (existing.lng - candidate.lng).abs() < 0.0003),
    );
    if (!duplicate) result.add(candidate);
  }
  return List.unmodifiable(result);
}

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({
    super.key,
    this.initialDestination,
    this.routeLocationUpdates,
    this.routeService,
    this.autoLocate = true,
  });

  final PlaceModel? initialDestination;
  final Stream<LatLng>? routeLocationUpdates;
  final MapRouteService? routeService;
  final bool autoLocate;

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final AnimationController _cameraAnimation;
  GovernorateProvider? _governorates;
  String? _lastGovernorateId;
  bool _lastFogEnabled = true;
  LatLng _cameraStart = _alexCenter;
  LatLng _cameraTarget = _alexCenter;
  double _cameraStartZoom = 12;
  double _cameraTargetZoom = 12;
  bool _mapReady = false;
  final Set<String> _selectedCategories = <String>{};
  PlaceModel? _selectedPlace;
  LatLng? _userLocation;
  bool _initialCentered = false;

  List<MapPoi> _atms = const [];
  late final MapRouteService _routeService;
  late final bool _ownsRouteService;
  MapRouteDestination? _routeDestination;
  List<LatLng> _fullRoute = const [];
  List<LatLng> _remainingRoute = const [];
  double _remainingDistanceMeters = 0;
  int _routeProgressIndex = 0;
  bool _routeLoading = false;
  bool _routeArrived = false;
  bool _arrivalAnnounced = false;
  StreamSubscription<LatLng>? _routePositionSubscription;
  bool _routePlannerOpen = false;
  List<PlaceModel> _plannedStops = const [];
  List<LatLng> _plannedRoute = const [];
  bool _plannedRouteLoading = false;
  int _routePlanRequestId = 0;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<PlaceModel>? _autoCheckInSubscription;
  bool _startingPositionUpdates = false;

  static const _alexCenter = LatLng(31.2001, 29.9187);
  @override
  void initState() {
    super.initState();
    _routeService = widget.routeService ?? MapRouteService();
    _ownsRouteService = widget.routeService == null;
    _cameraAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(_applyCameraAnimation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoCheckInLocationUpdates();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GovernorateProvider>();
    if (identical(_governorates, provider)) return;
    _governorates?.removeListener(_onGovernorateChanged);
    _governorates = provider;
    _lastGovernorateId = provider.activeGovernorate;
    _lastFogEnabled = provider.fogEnabled;
    _atms = _curatedAtmsFor(provider.activeGovernorate);
    provider.addListener(_onGovernorateChanged);
    if (provider.activeGovernorate == 'alexandria') {
      unawaited(_loadNearbyAtms(_userLocation ?? _alexCenter));
    }
  }

  void _onGovernorateChanged() {
    final id = _governorates?.activeGovernorate;
    final fogEnabled = _governorates?.fogEnabled ?? true;
    if (id == null) return;
    if (id == _lastGovernorateId) {
      if (fogEnabled == _lastFogEnabled) return;
      _lastFogEnabled = fogEnabled;
      if (!fogEnabled && !_routePlannerOpen) _fitToAllPlaces();
      return;
    }
    final governorate = EgyptGovernorate.byId[id];
    if (governorate == null) return;
    _lastGovernorateId = id;
    _lastFogEnabled = fogEnabled;
    setState(() {
      _selectedPlace = null;
      _selectedCategories.clear();
      _atms = _curatedAtmsFor(id);
      _plannedStops = _plannedStops
          .where(
            (place) => EgyptGovernorate.normalizeId(place.governorate) == id,
          )
          .toList(growable: false);
    });
    if (_routePlannerOpen) unawaited(_refreshPlannedRoute());
    if (id == 'alexandria') {
      unawaited(_loadNearbyAtms(_userLocation ?? _alexCenter));
    }
    if (!fogEnabled && !_routePlannerOpen) {
      _fitToAllPlaces();
    } else {
      _animateCameraTo(governorate);
    }
  }

  void _fitToAllPlaces() {
    if (!_mapReady || _routePlannerOpen) return;
    final places = context.read<PlaceProvider>().allPlaces;
    final points = <LatLng>[
      for (final place in places)
        if (place.isVisitable || place.isAtm) LatLng(place.lat, place.lng),
      for (final id in const ['alexandria', 'cairo', 'luxor', 'red_sea'])
        LatLng(
          EgyptGovernorate.byId[id]!.centerLat,
          EgyptGovernorate.byId[id]!.centerLng,
        ),
    ];
    if (points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(32, 110, 32, 90),
        ),
      );
    } catch (error) {
      debugPrint('MapViewScreen: could not fit all governorates: $error');
    }
  }

  void _onMapReady() {
    _mapReady = true;
    final initialDestination = widget.initialDestination;
    if (initialDestination != null) {
      final governorates = context.read<GovernorateProvider>();
      if (governorates.unlockedGovernorateIds.contains(
        initialDestination.governorate,
      )) {
        governorates.unlockAndSelectGovernorate(initialDestination.governorate);
      }
      setState(() => _selectedPlace = initialDestination);
      unawaited(_startRoute(MapRouteDestination.fromPlace(initialDestination)));
    } else if (!context.read<GovernorateProvider>().fogEnabled) {
      _fitToAllPlaces();
    } else if (widget.autoLocate) {
      _locateUser();
    }
  }

  void _animateCameraTo(EgyptGovernorate governorate) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _cameraStart = camera.center;
    _cameraTarget = LatLng(governorate.centerLat, governorate.centerLng);
    _cameraStartZoom = camera.zoom;
    _cameraTargetZoom = governorate.defaultZoom;
    _cameraAnimation.forward(from: 0);
  }

  void _applyCameraAnimation() {
    if (!_mapReady || !mounted) return;
    final progress = Curves.easeInOutCubic.transform(_cameraAnimation.value);
    _mapController.move(
      LatLng(
        _cameraStart.latitude +
            (_cameraTarget.latitude - _cameraStart.latitude) * progress,
        _cameraStart.longitude +
            (_cameraTarget.longitude - _cameraStart.longitude) * progress,
      ),
      _cameraStartZoom + (_cameraTargetZoom - _cameraStartZoom) * progress,
    );
  }

  void _startAutoCheckInLocationUpdates() {
    final places = context.read<PlaceProvider>();
    _autoCheckInSubscription = places.autoCheckIns.listen(
      _showAutoCheckInSnackBar,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('MapViewScreen auto check-in notification failed: $error');
      },
    );
  }

  Future<void> _subscribeToPositionUpdates(
    PlaceProvider places, {
    bool forRoute = false,
  }) async {
    if ((!forRoute && kIsWeb) ||
        _positionSubscription != null ||
        _startingPositionUpdates) {
      return;
    }
    _startingPositionUpdates = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return;
      }
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
            ),
          ).listen(
            (position) {
              unawaited(_handlePositionUpdate(places, position));
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'MapViewScreen location stream failed: $error\n$stackTrace',
              );
            },
          );
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen could not start auto check-in location updates: '
        '$error\n$stackTrace',
      );
    } finally {
      _startingPositionUpdates = false;
    }
  }

  Future<void> _handlePositionUpdate(
    PlaceProvider places,
    Position position,
  ) async {
    if (!mounted) return;
    final governorates = context.read<GovernorateProvider>();
    final location = LatLng(position.latitude, position.longitude);
    _updateUserLocation(location);
    CarPlayService.instance.updateLocation(
      location.latitude,
      location.longitude,
    );
    try {
      await governorates.syncWithCoordinates(
        location.latitude,
        location.longitude,
        availableGovernorateIds: places.availableGovernorateIds,
      );
      if (!kIsWeb) await _evaluateAutoCheckIn(places, position);
    } catch (error, stackTrace) {
      debugPrint('MapViewScreen position update failed: $error\n$stackTrace');
    }
  }

  Future<void> _evaluateAutoCheckIn(
    PlaceProvider places,
    Position position,
  ) async {
    try {
      await places.evaluateAutoCheckInForPosition(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (error, stackTrace) {
      debugPrint('MapViewScreen auto check-in failed: $error\n$stackTrace');
    }
  }

  void _showAutoCheckInSnackBar(PlaceModel place) {
    if (!mounted || (ModalRoute.of(context)?.isCurrent == false)) return;
    final locale = Localizations.localeOf(context).languageCode;
    final message = context.tr('auto_checkin_success', {
      'place': place.localizedName(locale),
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF059669),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _locateUser({bool move = false}) async {
    try {
      final governorates = context.read<GovernorateProvider>();
      final places = context.read<PlaceProvider>();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      CarPlayService.instance.updateLocation(here.latitude, here.longitude);
      _updateUserLocation(here);
      unawaited(_subscribeToPositionUpdates(places));
      await governorates.syncWithCoordinates(
        here.latitude,
        here.longitude,
        availableGovernorateIds: places.availableGovernorateIds,
      );
      await _evaluateAutoCheckIn(places, pos);
      if (move || !_initialCentered) {
        _initialCentered = true;
        _mapController.move(here, 13.5);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen: location detection failed: $error\n$stackTrace',
      );
    }
  }

  Future<LatLng> _resolveRouteOrigin() async {
    final destinationGovernorate = _routeDestinationGovernorate;
    if (_userLocation != null &&
        destinationGovernorate != null &&
        _isInsideGovernorate(_userLocation!, destinationGovernorate)) {
      return _userLocation!;
    }
    if (widget.routeLocationUpdates != null) {
      return _routeReferencePoint();
    }
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          destinationGovernorate != null &&
          _isInsideGovernorate(
            LatLng(lastKnown.latitude, lastKnown.longitude),
            destinationGovernorate,
          )) {
        final location = LatLng(lastKnown.latitude, lastKnown.longitude);
        _updateUserLocation(location);
        return location;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen: last-known route location unavailable: '
        '$error\n$stackTrace',
      );
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever &&
          await Geolocator.isLocationServiceEnabled()) {
        final current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        final location = LatLng(current.latitude, current.longitude);
        if (destinationGovernorate != null &&
            _isInsideGovernorate(location, destinationGovernorate)) {
          if (mounted) _updateUserLocation(location);
          return location;
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen: current route location unavailable: '
        '$error\n$stackTrace',
      );
    }
    return destinationGovernorate == null
        ? _routeReferencePoint()
        : LatLng(
            destinationGovernorate.centerLat,
            destinationGovernorate.centerLng,
          );
  }

  EgyptGovernorate? get _routeDestinationGovernorate {
    final destination = _routeDestination;
    if (destination == null) return null;
    final matchingPlace = context
        .read<PlaceProvider>()
        .allPlaces
        .where((place) => place.id == destination.id)
        .firstOrNull;
    final id = matchingPlace == null
        ? context.read<GovernorateProvider>().activeGovernorate
        : EgyptGovernorate.normalizeId(matchingPlace.governorate);
    return EgyptGovernorate.byId[id];
  }

  bool _isInsideGovernorate(LatLng point, EgyptGovernorate governorate) {
    var inside = false;
    final polygon = governorate.boundaryPolygon;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  LatLng _routeReferencePoint() {
    final reference = _mapReady
        ? _mapController.camera.center
        : _governorateReferencePoint();
    final destination = _routeDestination;
    if (destination != null &&
        MapRouteService.distanceMeters(reference, destination.point) <= 25) {
      return _governorateReferencePoint();
    }
    return reference;
  }

  LatLng _governorateReferencePoint() {
    final governorate =
        EgyptGovernorate.byId[context
            .read<GovernorateProvider>()
            .activeGovernorate] ??
        EgyptGovernorate.byId['alexandria']!;
    return LatLng(governorate.centerLat, governorate.centerLng);
  }

  Future<void> _startRoute(MapRouteDestination destination) async {
    setState(() {
      _routeDestination = destination;
      _selectedPlace = null;
      _routeLoading = true;
      _routeArrived = false;
      _arrivalAnnounced = false;
      _fullRoute = const [];
      _remainingRoute = const [];
      _remainingDistanceMeters = 0;
      _routeProgressIndex = 0;
    });
    try {
      final origin = await _resolveRouteOrigin();
      if (!mounted || _routeDestination?.id != destination.id) return;
      final route = await _routeService.getWalkingRoute(
        origin,
        destination.point,
      );
      if (!mounted || _routeDestination?.id != destination.id) return;
      setState(() {
        _fullRoute = route;
        _routeLoading = false;
        _userLocation = origin;
      });
      _applyRouteProgress(origin);
      _fitToActiveRoute();
      if (widget.routeLocationUpdates != null) {
        _routePositionSubscription ??= widget.routeLocationUpdates!.listen(
          _updateUserLocation,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'MapViewScreen injected route location stream failed: '
              '$error\n$stackTrace',
            );
          },
        );
      } else {
        unawaited(
          _subscribeToPositionUpdates(
            context.read<PlaceProvider>(),
            forRoute: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('MapViewScreen: route could not start: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _routeDestination = null;
        _routeLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('route_start_failed'))));
    }
  }

  void _toggleRoutePlanner() {
    setState(() {
      _routePlannerOpen = !_routePlannerOpen;
      _selectedPlace = null;
      if (!_routePlannerOpen) {
        _plannedStops = const [];
        _plannedRoute = const [];
        _plannedRouteLoading = false;
        _routePlanRequestId++;
      }
    });
    if (_routePlannerOpen) unawaited(_refreshPlannedRoute());
  }

  void _togglePlannedStop(PlaceModel place) {
    final selectedIndex = _plannedStops.indexWhere(
      (stop) => stop.id == place.id,
    );
    setState(() {
      final nextStops = List<PlaceModel>.of(_plannedStops);
      if (selectedIndex >= 0) {
        nextStops.removeAt(selectedIndex);
      } else {
        nextStops.add(place);
      }
      _plannedStops = List.unmodifiable(nextStops);
      _selectedPlace = null;
    });
    final governorate = EgyptGovernorate
        .byId[context.read<GovernorateProvider>().activeGovernorate];
    if (governorate != null) _fitToPlannedRoute(governorate);
    unawaited(_refreshPlannedRoute());
  }

  LatLng _routePlannerOrigin(EgyptGovernorate governorate) {
    final location = _userLocation;
    if (location != null && _isInsideGovernorate(location, governorate)) {
      return location;
    }
    return LatLng(governorate.centerLat, governorate.centerLng);
  }

  List<PlaceModel> _sortedPlannerPlaces(
    Iterable<PlaceModel> places,
    EgyptGovernorate governorate,
  ) {
    final origin = _plannedStops.isNotEmpty
        ? LatLng(_plannedStops.last.lat, _plannedStops.last.lng)
        : _routePlannerOrigin(governorate);
    final sorted = places.where((place) {
      return place.isVisitable &&
          EgyptGovernorate.normalizeId(place.governorate) == governorate.id &&
          !_plannedStops.any((stop) => stop.id == place.id);
    }).toList();
    sorted.sort((a, b) {
      final distanceComparison = MapRouteService.distanceMeters(
        origin,
        LatLng(a.lat, a.lng),
      ).compareTo(MapRouteService.distanceMeters(origin, LatLng(b.lat, b.lng)));
      if (distanceComparison != 0) return distanceComparison;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _fitToPlannedRoute(EgyptGovernorate governorate) {
    if (!_mapReady || !_routePlannerOpen || _plannedStops.isEmpty) return;
    final points = <LatLng>[
      _routePlannerOrigin(governorate),
      ..._plannedStops.map((place) => LatLng(place.lat, place.lng)),
      ..._plannedRoute,
    ];
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 430),
        ),
      );
    } catch (error) {
      debugPrint('MapViewScreen: could not fit planned route: $error');
    }
  }

  double _plannedDistanceMeters(EgyptGovernorate governorate) {
    if (_plannedRoute.length > 1) {
      var distance = 0.0;
      for (var index = 1; index < _plannedRoute.length; index++) {
        distance += MapRouteService.distanceMeters(
          _plannedRoute[index - 1],
          _plannedRoute[index],
        );
      }
      return distance;
    }
    var origin = _routePlannerOrigin(governorate);
    var distance = 0.0;
    for (final stop in _plannedStops) {
      final destination = LatLng(stop.lat, stop.lng);
      distance += MapRouteService.distanceMeters(origin, destination);
      origin = destination;
    }
    return distance;
  }

  String _formatWalkingTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Future<void> _refreshPlannedRoute() async {
    final requestId = ++_routePlanRequestId;
    final governorate = EgyptGovernorate
        .byId[context.read<GovernorateProvider>().activeGovernorate];
    final stops = _plannedStops;
    if (!_routePlannerOpen || governorate == null || stops.isEmpty) {
      if (!mounted) return;
      setState(() {
        _plannedRoute = const [];
        _plannedRouteLoading = false;
      });
      return;
    }
    setState(() {
      _plannedRoute = const [];
      _plannedRouteLoading = true;
    });
    _fitToPlannedRoute(governorate);
    try {
      final route = <LatLng>[];
      var origin = _routePlannerOrigin(governorate);
      for (final stop in stops) {
        final destination = LatLng(stop.lat, stop.lng);
        final segment = await _routeService.getWalkingRoute(
          origin,
          destination,
        );
        if (route.isEmpty) {
          route.addAll(segment);
        } else {
          route.addAll(segment.skip(1));
        }
        origin = destination;
      }
      if (!mounted || requestId != _routePlanRequestId) return;
      setState(() {
        _plannedRoute = List.unmodifiable(route);
        _plannedRouteLoading = false;
      });
      _fitToPlannedRoute(governorate);
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen: planned route could not refresh: $error\n$stackTrace',
      );
      if (!mounted || requestId != _routePlanRequestId) return;
      setState(() {
        _plannedRoute = const [];
        _plannedRouteLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('route_start_failed'))));
    }
  }

  void _selectPlannerGovernorate(String governorateId) {
    if (_governorates?.unlockAndSelectGovernorate(governorateId) != true) {
      return;
    }
    final governorate = EgyptGovernorate.byId[governorateId];
    if (governorate != null) _animateCameraTo(governorate);
  }

  Widget _plannedStopBadge(PlaceModel place, bool showGlow) {
    final stopIndex = _plannedStops.indexWhere((stop) => stop.id == place.id);
    if (stopIndex >= 0) {
      return Container(
        key: ValueKey('map-route-stop-${stopIndex + 1}'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            if (showGlow)
              const BoxShadow(color: Color(0x668B5CF6), blurRadius: 9),
          ],
        ),
        child: Center(
          child: Text(
            '${stopIndex + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _colorForCategory(place.category),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          if (showGlow)
            BoxShadow(
              color: _colorForCategory(place.category).withValues(alpha: 0.45),
              blurRadius: 8,
            ),
        ],
      ),
      child: Icon(
        _iconForCategory(place.category),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildRoutePlannerPanel(
    BuildContext context,
    EgyptGovernorate activeGovernorate,
    List<PlaceModel> allPlaces,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final plannerPlaces = _sortedPlannerPlaces(allPlaces, activeGovernorate);
    final distanceMeters = _plannedDistanceMeters(activeGovernorate);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      height: 420,
      child: Material(
        key: const ValueKey('map-route-planner-panel'),
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        elevation: 10,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Walking Route',
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_plannedRouteLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    key: const ValueKey('map-route-planner-close'),
                    tooltip: 'Close route planner',
                    onPressed: _toggleRoutePlanner,
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  key: const ValueKey('route-planner-governorate-chips'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final id in const [
                      'alexandria',
                      'cairo',
                      'luxor',
                      'red_sea',
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          key: ValueKey('route-planner-governorate-$id'),
                          label: Text(
                            locale == 'ar'
                                ? EgyptGovernorate.byId[id]!.nameAr
                                : EgyptGovernorate.byId[id]!.nameEn,
                          ),
                          selected: activeGovernorate.id == id,
                          onSelected: (selected) {
                            if (selected) _selectPlannerGovernorate(id);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selected Stops / المحطات المختارة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPri,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(distanceMeters / 1000).toStringAsFixed(1)} km · '
                      '${_formatWalkingTime(MapRouteService.walkingMinutes(distanceMeters))}',
                      style: TextStyle(
                        color: context.textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 54,
                child: ListView(
                  key: const ValueKey('map-route-selected-stops'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final entry in _plannedStops.asMap().entries)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Container(
                          padding: const EdgeInsetsDirectional.only(
                            start: 8,
                            end: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.bgAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(
                                0xFF14B8A6,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF14B8A6),
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 130,
                                ),
                                child: Text(
                                  entry.value.localizedName(locale),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textPri,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: ValueKey(
                                  'map-route-remove-stop-${entry.value.id}',
                                ),
                                tooltip: 'Remove stop',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _togglePlannedStop(entry.value),
                                icon: const Icon(Icons.close_rounded, size: 17),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pick places',
                        style: TextStyle(
                          color: context.textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_plannedStops.length} stops',
                      style: TextStyle(
                        color: context.textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: plannerPlaces.isEmpty
                    ? Center(
                        child: Text(
                          'No visitable places in this governorate.',
                          style: TextStyle(color: context.textSec),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('route-planner-place-list'),
                        itemCount: plannerPlaces.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final place = plannerPlaces[index];
                          final stopIndex = _plannedStops.indexWhere(
                            (stop) => stop.id == place.id,
                          );
                          return ListTile(
                            key: ValueKey('route-planner-place-${place.id}'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: stopIndex >= 0
                                  ? const Color(0xFF8B5CF6)
                                  : _colorForCategory(place.category),
                              child: stopIndex >= 0
                                  ? Text(
                                      '${stopIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : Icon(
                                      _iconForCategory(place.category),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                            ),
                            title: Text(
                              place.localizedName(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textPri,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Icon(
                              stopIndex >= 0
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              color: context.textSec,
                              size: 20,
                            ),
                            onTap: () => _togglePlannedStop(place),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateUserLocation(LatLng location) {
    if (!mounted) return;
    final previousLocation = _userLocation;
    final governorate = EgyptGovernorate
        .byId[context.read<GovernorateProvider>().activeGovernorate];
    final originMoved =
        previousLocation == null ||
        MapRouteService.distanceMeters(previousLocation, location) >= 100 ||
        (governorate != null &&
            _isInsideGovernorate(previousLocation, governorate) !=
                _isInsideGovernorate(location, governorate));
    setState(() => _userLocation = location);
    _applyRouteProgress(location);
    if (_routePlannerOpen && _plannedStops.isNotEmpty && originMoved) {
      unawaited(_refreshPlannedRoute());
    }
  }

  void _applyRouteProgress(LatLng location) {
    final destination = _routeDestination;
    if (destination == null || _fullRoute.length < 2 || !mounted) return;
    final progress = MapRouteService.progressAlongRoute(
      route: _fullRoute,
      currentLocation: location,
      minimumSegmentIndex: _routeProgressIndex,
    );
    final arrived =
        _routeArrived ||
        MapRouteService.distanceMeters(location, destination.point) <= 25;
    setState(() {
      _remainingRoute = progress.points;
      _remainingDistanceMeters = progress.remainingDistanceMeters;
      _routeProgressIndex = progress.nextSegmentIndex;
      _routeArrived = arrived;
    });
    if (arrived && !_arrivalAnnounced) _announceArrival(destination);
    if (_mapReady && _routeDestination != null) {
      try {
        _mapController.move(location, _mapController.camera.zoom);
      } catch (error) {
        debugPrint('MapViewScreen: could not follow route location: $error');
      }
    }
  }

  void _announceArrival(MapRouteDestination destination) {
    _arrivalAnnounced = true;
    final locale = Localizations.localeOf(context).languageCode;
    final message = context.tr('route_arrived_at', {
      'place': destination.localizedName(locale),
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _fitToActiveRoute() {
    final destination = _routeDestination;
    if (!_mapReady || _remainingRoute.length < 2 || destination == null) {
      return;
    }
    try {
      final camera = _mapController.camera;
      final targetCamera = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          ..._remainingRoute,
          if (_userLocation != null) _userLocation!,
          destination.point,
        ]),
        padding: const EdgeInsets.fromLTRB(32, 120, 32, 150),
      ).fit(camera);
      _cameraStart = camera.center;
      _cameraTarget = targetCamera.center;
      _cameraStartZoom = camera.zoom;
      _cameraTargetZoom = targetCamera.zoom;
      _cameraAnimation.forward(from: 0);
    } catch (error) {
      debugPrint('MapViewScreen: could not fit walking route: $error');
    }
  }

  void _endRoute() {
    setState(() {
      _routeDestination = null;
      _fullRoute = const [];
      _remainingRoute = const [];
      _remainingDistanceMeters = 0;
      _routeLoading = false;
      _routeArrived = false;
      _arrivalAnnounced = false;
      _routeProgressIndex = 0;
    });
  }

  void _showAtmSheet(BuildContext context, MapPoi atm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => AtmSheet(
        atm: atm,
        onRoute: (poi) {
          Navigator.pop(ctx);
          unawaited(_startRoute(MapRouteDestination.fromAtm(poi)));
        },
      ),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (!_selectedCategories.add(category)) {
        _selectedCategories.remove(category);
      }
    });
  }

  void _selectAllCategories() {
    setState(_selectedCategories.clear);
  }

  List<MapPoi> _curatedAtmsFor(String governorateId) {
    governorateId = EgyptGovernorate.normalizeId(governorateId);
    final governorateName =
        EgyptGovernorate.byId[governorateId]?.nameEn ?? governorateId;
    final candidates = <MapPoi>[
      if (governorateId == 'alexandria') ...AtmService.curatedAlexandriaAtms,
      ...context
          .read<PlaceProvider>()
          .allPlaces
          .where(
            (place) =>
                EgyptGovernorate.normalizeId(place.governorate) ==
                    governorateId &&
                place.isAtm,
          )
          .map(
            (place) => MapPoi(
              id: place.id,
              name: place.nameEn,
              address: place.address,
              governorate: governorateName,
              lat: place.lat,
              lng: place.lng,
              category: 'ATMs',
              brand: place.nameEn.split(' ').first,
              icon: Icons.atm_rounded,
              color: place.id.contains('_cib_')
                  ? const Color(0xFFED1C24)
                  : place.id.contains('_nbe_')
                  ? const Color(0xFF0033A0)
                  : place.id.contains('_qnb_')
                  ? const Color(0xFF8B1A1A)
                  : const Color(0xFF1F4E79),
            ),
          ),
    ];
    return _mergeAtms(candidates);
  }

  Future<void> _loadNearbyAtms(LatLng center) async {
    if (context.read<GovernorateProvider>().activeGovernorate != 'alexandria') {
      return;
    }
    try {
      final nearbyAtms = await AtmService.fetchNearby(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted ||
          !_showAtms ||
          context.read<GovernorateProvider>().activeGovernorate !=
              'alexandria') {
        return;
      }
      setState(() => _atms = _mergeAtms([..._atms, ...nearbyAtms]));
    } catch (error, stackTrace) {
      debugPrint(
        'MapViewScreen: optional nearby ATM refresh failed: '
        '$error\n$stackTrace',
      );
    }
  }

  IconData _iconForCategory(String category) {
    switch (_normalizeMapCategory(category)) {
      case 'historical':
        return Icons.account_balance_rounded;
      case 'culture':
        return Icons.museum_rounded;
      case 'nature':
        return Icons.park_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'cafes':
        return Icons.local_cafe_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'mosques':
        return Icons.mosque_rounded;
      case 'churches':
        return Icons.church_rounded;
      case 'hotels':
        return Icons.bed_rounded;
      case 'atms':
        return Icons.atm_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (_normalizeMapCategory(category)) {
      case 'historical':
        return const Color(0xFF8B5CF6);
      case 'culture':
        return const Color(0xFFEC4899);
      case 'nature':
        return const Color(0xFF10B981);
      case 'food':
        return const Color(0xFFF59E0B);
      case 'cafes':
        return const Color(0xFF8B5E3C);
      case 'shopping':
        return const Color(0xFF3B82F6);
      case 'mosques':
        return const Color(0xFF14B8A6);
      case 'churches':
        return const Color(0xFFF97316);
      case 'hotels':
        return const Color(0xFF6A1B9A);
      case 'atms':
        return const Color(0xFF10B981);
      default:
        return AppColors.primary;
    }
  }

  List<PlaceModel> _filtered(List<PlaceModel> all) {
    if (_selectedCategories.isEmpty) return all;
    return all
        .where(
          (place) => _selectedCategories.any(
            (selected) =>
                _normalizeMapCategory(selected) ==
                _normalizeMapCategory(place.category),
          ),
        )
        .toList();
  }

  bool get _showAtms => _selectedCategories.contains('ATMs');
  bool get _navigationFocusMode => _routeDestination != null && !_routeArrived;

  @override
  void dispose() {
    _governorates?.removeListener(_onGovernorateChanged);
    unawaited(_positionSubscription?.cancel());
    unawaited(_autoCheckInSubscription?.cancel());
    unawaited(_routePositionSubscription?.cancel());
    if (_ownsRouteService) _routeService.close();
    _cameraAnimation.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<PlaceProvider>();
    final governorateProvider = context.watch<GovernorateProvider>();
    final activeGovernorate =
        EgyptGovernorate.byId[EgyptGovernorate.normalizeId(
          governorateProvider.activeGovernorate,
        )] ??
        EgyptGovernorate.byId['alexandria']!;
    final places = placeProvider.places;
    final allPlaces = placeProvider.allPlaces;
    final visitedPlaceIds = context.watch<TripProvider>().visitedPlaceIds;
    final visibleSource = governorateProvider.fogEnabled
        ? places
        : allPlaces.where((place) => place.isVisitable).toList(growable: false);
    final visible = _filtered(visibleSource);
    final mapAtms = _mergeAtms([
      for (final id
          in governorateProvider.fogEnabled
              ? [activeGovernorate.id]
              : const ['alexandria', 'cairo', 'luxor', 'red_sea'])
        ..._curatedAtmsFor(id),
      ..._atms,
    ]);
    final visibleMarkerCount = _routePlannerOpen
        ? _plannedStops.length
        : visible.length + (_showAtms ? mapAtms.length : 0);
    final plannedRoutePoints = _plannedRoute.length > 1
        ? _plannedRoute
        : <LatLng>[
            if (_routePlannerOpen) _routePlannerOrigin(activeGovernorate),
            ..._plannedStops.map((place) => LatLng(place.lat, place.lng)),
          ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                activeGovernorate.centerLat,
                activeGovernorate.centerLng,
              ),
              initialZoom: activeGovernorate.defaultZoom,
              minZoom: 5,
              maxZoom: 18,
              onMapReady: _onMapReady,
              onTap: (_, __) => setState(() => _selectedPlace = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.alsaba.egyptlore',
                maxNativeZoom: 17,
                tileProvider: OfflineTileProvider(),
              ),
              if (!_navigationFocusMode && !_routePlannerOpen)
                GovernorateFogLayer(
                  places: allPlaces,
                  visitedPlaceIds: visitedPlaceIds,
                ),
              if ((_routePlannerOpen && plannedRoutePoints.length > 1) ||
                  (!_routePlannerOpen && _remainingRoute.length > 1))
                PolylineLayer(
                  key: const ValueKey('map-route-polyline-layer'),
                  polylines: [
                    Polyline(
                      points: _routePlannerOpen
                          ? plannedRoutePoints
                          : _remainingRoute,
                      color: _routePlannerOpen
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFF00D9FF),
                      strokeWidth: 7,
                      borderColor: const Color(0xFF10243A),
                      borderStrokeWidth: 5,
                    ),
                  ],
                ),
              Builder(
                builder: (mapContext) {
                  final camera = MapCamera.of(mapContext);
                  final bounds = camera.visibleBounds;
                  const padding = 0.008;
                  bool inViewport(LatLng point) =>
                      point.latitude >= bounds.south - padding &&
                      point.latitude <= bounds.north + padding &&
                      point.longitude >= bounds.west - padding &&
                      point.longitude <= bounds.east + padding;
                  final markerPlaces = _navigationFocusMode
                      ? <PlaceModel>[]
                      : _routePlannerOpen
                      ? <PlaceModel>[..._plannedStops]
                      : <PlaceModel>[...visible];
                  if (_selectedPlace != null &&
                      EgyptGovernorate.normalizeId(
                            _selectedPlace!.governorate,
                          ) ==
                          activeGovernorate.id &&
                      !markerPlaces.any(
                        (place) => place.id == _selectedPlace!.id,
                      )) {
                    markerPlaces.add(_selectedPlace!);
                  }
                  final visiblePlaces = markerPlaces.where((place) {
                    final point = LatLng(place.lat, place.lng);
                    return _routePlannerOpen ||
                        place.id == _selectedPlace?.id ||
                        inViewport(point);
                  });
                  final showMarkerGlow = camera.zoom >= 13.5;
                  return MarkerLayer(
                    markers: [
                      if (_routePlannerOpen)
                        Marker(
                          point: _routePlannerOrigin(activeGovernorate),
                          width: 70,
                          height: 34,
                          child: Container(
                            key: const ValueKey('map-route-user-location'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.45),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? 'موقعك'
                                    : 'You',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 26,
                          height: 26,
                          child: Container(
                            key: const ValueKey('map-route-user-location'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_navigationFocusMode)
                        Marker(
                          point: _routeDestination!.point,
                          width: 44,
                          height: 44,
                          child: Container(
                            key: const ValueKey('map-route-destination-marker'),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A36),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5A36,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      if (!_navigationFocusMode &&
                          !_routePlannerOpen &&
                          _showAtms)
                        for (final atm in mapAtms.where(
                          (atm) => inViewport(LatLng(atm.lat, atm.lng)),
                        ))
                          Marker(
                            point: LatLng(atm.lat, atm.lng),
                            width: 40,
                            height: 40,
                            child: RepaintBoundary(
                              child: GestureDetector(
                                key: ValueKey('map-atm-marker-${atm.id}'),
                                onTap: () {
                                  setState(() => _selectedPlace = null);
                                  _showAtmSheet(context, atm);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: atm.color,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      if (showMarkerGlow)
                                        BoxShadow(
                                          color: atm.color.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
                                        ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Icon(
                                    atm.icon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      for (final p in visiblePlaces)
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: _routePlannerOpen
                              ? 42
                              : p.isVisitable && visitedPlaceIds.contains(p.id)
                              ? 50
                              : 44,
                          height: _routePlannerOpen
                              ? 42
                              : p.isVisitable && visitedPlaceIds.contains(p.id)
                              ? 50
                              : 44,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              key: ValueKey('map-place-marker-${p.id}'),
                              onTap: () {
                                if (_routePlannerOpen) {
                                  _togglePlannedStop(p);
                                } else {
                                  setState(() => _selectedPlace = p);
                                }
                                _mapController.move(LatLng(p.lat, p.lng), 14);
                              },
                              child: _routePlannerOpen
                                  ? _plannedStopBadge(p, showMarkerGlow)
                                  : p.isVisitable &&
                                        visitedPlaceIds.contains(p.id)
                                  ? Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              if (showMarkerGlow ||
                                                  p.id == _selectedPlace?.id)
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF059669,
                                                  ).withValues(alpha: 0.5),
                                                  blurRadius: 9,
                                                  spreadRadius: 2,
                                                ),
                                            ],
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        Positioned(
                                          top: -1,
                                          right: -1,
                                          child: Container(
                                            width: 19,
                                            height: 19,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4C542),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Color(0xFF14532D),
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: _colorForCategory(p.category),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          if (showMarkerGlow ||
                                              p.id == _selectedPlace?.id)
                                            BoxShadow(
                                              color: _colorForCategory(
                                                p.category,
                                              ).withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Icon(
                                        _iconForCategory(p.category),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          if (!_navigationFocusMode)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton.filled(
                      key: const ValueKey('map-view-back-button'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: context.cardColor,
                        foregroundColor: context.textPri,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        key: const ValueKey('map-view-header-bar'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('map_title', {
                                  'n': '$visibleMarkerCount',
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.textPri,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: GovernorateSelector(
                                buttonKey: const ValueKey(
                                  'map-view-governorate-pill',
                                ),
                                compact: true,
                                onExploreAll: () =>
                                    showGovernorateExplorerSheet(
                                      context,
                                      places: allPlaces,
                                      visitedPlaceIds: visitedPlaceIds,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_routeDestination != null)
            Positioned(
              top: _navigationFocusMode
                  ? MediaQuery.paddingOf(context).top + 8
                  : 82,
              left: 16,
              right: 16,
              child: MapRouteHud(
                destinationName: _routeDestination!.localizedName(
                  Localizations.localeOf(context).languageCode,
                ),
                distance: MapRouteService.formatDistance(
                  _remainingDistanceMeters,
                ),
                estimatedMinutes: MapRouteService.walkingMinutes(
                  _remainingDistanceMeters,
                ),
                isLoading: _routeLoading,
                isArrived: _routeArrived,
                onEndRoute: _endRoute,
              ),
            ),
          if (_selectedPlace != null &&
              !_navigationFocusMode &&
              !_routePlannerOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _SelectedPlaceCard(
                key: const ValueKey('map-selected-place-card'),
                place: _selectedPlace!,
                color: _colorForCategory(_selectedPlace!.category),
                icon: _iconForCategory(_selectedPlace!.category),
                onClose: () => setState(() => _selectedPlace = null),
                onRoute: () => unawaited(
                  _startRoute(MapRouteDestination.fromPlace(_selectedPlace!)),
                ),
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaceDetailsScreen(place: _selectedPlace!),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            right: 16,
            bottom: _routePlannerOpen
                ? 440
                : _selectedPlace != null
                ? 220
                : 72,
            child: FloatingActionButton.small(
              heroTag: 'locate-fab',
              tooltip: context.tr('map_my_location'),
              onPressed: () => _locateUser(move: true),
              backgroundColor: Theme.of(context).cardColor,
              child: Icon(
                Icons.my_location_rounded,
                size: 20,
                color: context.textPri,
              ),
            ),
          ),
          if (_routePlannerOpen)
            _buildRoutePlannerPanel(context, activeGovernorate, allPlaces),
          if (!_navigationFocusMode && !_routePlannerOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: _selectedPlace != null ? 150 : 16,
              child: KeyedSubtree(
                key: const ValueKey('map-category-filter-bar'),
                child: _CategoryFilter(
                  selectedCategories: _selectedCategories,
                  onToggleCategory: _toggleCategory,
                  onSelectAll: _selectAllCategories,
                  colorOf: _colorForCategory,
                  iconOf: _iconForCategory,
                ),
              ),
            ),
          if (!_navigationFocusMode && !_routePlannerOpen)
            Positioned(
              left: 16,
              bottom: _selectedPlace != null ? 220 : 76,
              child: FilledButton.icon(
                key: const ValueKey('map-open-route-planner'),
                onPressed: _toggleRoutePlanner,
                icon: const Icon(Icons.directions_walk_rounded, size: 18),
                label: const Text('Walking Route'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: context.textPri,
                  elevation: 5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  final PlaceModel place;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onRoute;

  const _SelectedPlaceCard({
    super.key,
    required this.place,
    required this.color,
    required this.icon,
    required this.onClose,
    required this.onOpen,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.localizedName(
                        Localizations.localeOf(context).languageCode,
                      ),
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _catLabel(context, place.category),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          place.rating.toString(),
                          style: TextStyle(
                            color: context.textPri,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: context.hintColor,
                tooltip: context.tr('map_close'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RouteOnMapButton(onPressed: onRoute),
                ),
              ),
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: color,
                tooltip: context.tr('map_open_details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final Set<String> selectedCategories;
  final ValueChanged<String> onToggleCategory;
  final VoidCallback onSelectAll;
  final Color Function(String) colorOf;
  final IconData Function(String) iconOf;

  const _CategoryFilter({
    required this.selectedCategories,
    required this.onToggleCategory,
    required this.onSelectAll,
    required this.colorOf,
    required this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    const categories = [
      'Historical',
      'Culture',
      'Nature',
      'Food',
      'Cafes',
      'Shopping',
      'Mosques',
      'Churches',
      'Hotels',
      'ATMs',
    ];
    final children = <Widget>[];

    Widget buildChip({
      required String category,
      required bool selected,
      required VoidCallback onPressed,
      required Color color,
      required IconData icon,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          key: ValueKey('map-filter-chip-${category.toLowerCase()}'),
          selected: selected,
          onSelected: (_) => onPressed(),
          avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
          label: Text(
            _catLabel(context, category),
            style: TextStyle(
              color: selected ? Colors.white : context.textPri,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          backgroundColor: context.cardColor,
          selectedColor: color,
          checkmarkColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? color : context.cardColor,
              width: 1.5,
            ),
          ),
        ),
      );
    }

    children.add(
      buildChip(
        category: 'All',
        selected: selectedCategories.isEmpty,
        onPressed: onSelectAll,
        color: AppColors.primary,
        icon: Icons.apps_rounded,
      ),
    );
    for (final category in categories) {
      children.add(
        buildChip(
          category: category,
          selected: selectedCategories.contains(category),
          onPressed: () => onToggleCategory(category),
          color: colorOf(category),
          icon: iconOf(category),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        child: Row(children: children),
      ),
    );
  }
}
