import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/map_route_service.dart';
import '../../core/services/governorate_service.dart';
import '../../data/models/egypt_governorate.dart';
import '../../data/models/place_model.dart';
import '../../logic/governorate_provider.dart';
import '../../logic/place_provider.dart';
import '../../l10n/app_strings.dart';

class WalkingRoutesScreen extends StatefulWidget {
  const WalkingRoutesScreen({
    super.key,
    this.routeService,
    this.locationProvider,
  });

  final MapRouteService? routeService;
  final Future<LatLng?> Function()? locationProvider;

  @override
  State<WalkingRoutesScreen> createState() => _WalkingRoutesScreenState();
}

class _WalkingRoutesScreenState extends State<WalkingRoutesScreen> {
  final List<PlaceModel> _selected = [];
  final MapController _mapController = MapController();

  late final MapRouteService _routeService;
  late final bool _ownsRouteService;
  GovernorateProvider? _governorates;
  String? _lastGovernorateId;
  LatLng? _userLocation;
  List<LatLng> _routePoints = const [];
  bool _routeLoading = false;
  bool _mapReady = false;
  int _routeRequestId = 0;
  int _locationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _routeService = widget.routeService ?? MapRouteService();
    _ownsRouteService = widget.routeService == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshUserLocation());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final governorates = context.read<GovernorateProvider>();
    if (identical(_governorates, governorates)) return;
    _governorates?.removeListener(_onGovernorateChanged);
    _governorates = governorates;
    _lastGovernorateId = governorates.activeGovernorate;
    governorates.addListener(_onGovernorateChanged);
  }

  @override
  void dispose() {
    _governorates?.removeListener(_onGovernorateChanged);
    _mapController.dispose();
    if (_ownsRouteService) _routeService.close();
    super.dispose();
  }

  void _onGovernorateChanged() {
    final id = EgyptGovernorate.normalizeId(
      _governorates?.activeGovernorate ?? '',
    );
    if (id.isEmpty || id == _lastGovernorateId) return;
    _lastGovernorateId = id;
    final governorate = EgyptGovernorate.byId[id];
    _routeRequestId++;
    setState(() {
      _selected.removeWhere(
        (place) => EgyptGovernorate.normalizeId(place.governorate) != id,
      );
      _routePoints = const [];
      _routeLoading = false;
    });
    if (_mapReady && governorate != null) {
      _mapController.move(
        LatLng(governorate.centerLat, governorate.centerLng),
        governorate.defaultZoom,
      );
    }
    unawaited(_refreshUserLocation());
    if (_selected.isNotEmpty) unawaited(_refreshRoute());
  }

  LatLng _routeOrigin(EgyptGovernorate governorate) {
    final location = _userLocation;
    if (location != null &&
        GovernorateService.containsCoordinates(
          governorate,
          location.latitude,
          location.longitude,
        )) {
      return location;
    }
    return LatLng(governorate.centerLat, governorate.centerLng);
  }

  Future<LatLng?> _readLiveLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }

    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
    return LatLng(current.latitude, current.longitude);
  }

  Future<void> _refreshUserLocation() async {
    final requestId = ++_locationRequestId;
    final governorateId = _governorates?.activeGovernorate;
    try {
      final locationProvider = widget.locationProvider;
      final location = locationProvider == null
          ? await _readLiveLocation()
          : await locationProvider();
      if (!mounted ||
          requestId != _locationRequestId ||
          governorateId != _governorates?.activeGovernorate ||
          location == null ||
          !location.latitude.isFinite ||
          !location.longitude.isFinite) {
        return;
      }
      setState(() => _userLocation = location);
      if (_selected.isNotEmpty) unawaited(_refreshRoute());
    } catch (error, stackTrace) {
      debugPrint(
        'WalkingRoutesScreen: location lookup failed; using governorate '
        'anchor: $error\n$stackTrace',
      );
    }
  }

  double _routeDistanceMeters(EgyptGovernorate governorate) {
    if (_routePoints.length > 1) {
      var distance = 0.0;
      for (var index = 1; index < _routePoints.length; index++) {
        distance += MapRouteService.distanceMeters(
          _routePoints[index - 1],
          _routePoints[index],
        );
      }
      return distance;
    }

    var origin = _routeOrigin(governorate);
    var total = 0.0;
    for (final stop in _selected) {
      final destination = LatLng(stop.lat, stop.lng);
      total += MapRouteService.distanceMeters(origin, destination);
      origin = destination;
    }
    return total;
  }

  List<PlaceModel> _sortedPlaces(
    Iterable<PlaceModel> places,
    EgyptGovernorate governorate,
  ) {
    final origin = _selected.isNotEmpty
        ? LatLng(_selected.last.lat, _selected.last.lng)
        : _routeOrigin(governorate);
    final sorted = places
        .where(
          (place) =>
              place.isVisitable &&
              EgyptGovernorate.normalizeId(place.governorate) == governorate.id,
        )
        .toList();
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

  Future<void> _refreshRoute() async {
    final requestId = ++_routeRequestId;
    final governorate =
        EgyptGovernorate.byId[_governorates?.activeGovernorate ?? 'alexandria'];
    final stops = List<PlaceModel>.of(_selected);
    if (governorate == null || stops.isEmpty) {
      if (!mounted) return;
      setState(() {
        _routePoints = const [];
        _routeLoading = false;
      });
      return;
    }
    setState(() {
      _routePoints = const [];
      _routeLoading = true;
    });

    try {
      final route = <LatLng>[];
      var origin = _routeOrigin(governorate);
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
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routePoints = List.unmodifiable(route);
        _routeLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'WalkingRoutesScreen: route could not refresh: $error\n$stackTrace',
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routePoints = const [];
        _routeLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('route_start_failed'))));
    }
  }

  void _togglePlace(PlaceModel p) {
    final governorateId = _governorates?.activeGovernorate;
    if (!p.isVisitable ||
        governorateId == null ||
        EgyptGovernorate.normalizeId(p.governorate) != governorateId) {
      return;
    }
    final idx = _selected.indexWhere((s) => s.id == p.id);
    if (idx < 0 && _selected.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('max_route_places')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(p);
      }
    });
    unawaited(_refreshRoute());
    if (_mapReady && _selected.isNotEmpty) {
      final last = _selected.last;
      _mapController.move(LatLng(last.lat, last.lng), 13);
    }
  }

  void _autoSortByNearest(EgyptGovernorate governorate) {
    if (_selected.length < 2) return;
    setState(() {
      final remaining = List<PlaceModel>.of(_selected);
      final ordered = <PlaceModel>[];
      var origin = _routeOrigin(governorate);
      while (remaining.isNotEmpty) {
        remaining.sort(
          (a, b) => MapRouteService.distanceMeters(origin, LatLng(a.lat, a.lng))
              .compareTo(
                MapRouteService.distanceMeters(origin, LatLng(b.lat, b.lng)),
              ),
        );
        final next = remaining.removeAt(0);
        ordered.add(next);
        origin = LatLng(next.lat, next.lng);
      }
      _selected
        ..clear()
        ..addAll(ordered);
    });
    unawaited(_refreshRoute());
  }

  void _clear() {
    _routeRequestId++;
    setState(() {
      _selected.clear();
      _routePoints = const [];
      _routeLoading = false;
    });
  }

  void _selectGovernorate(String governorateId) {
    _governorates?.unlockAndSelectGovernorate(governorateId);
  }

  Widget _placeMarker(PlaceModel place, int stopIndex) {
    final selected = stopIndex >= 0;
    final color = _colorForCategory(place.category);
    return GestureDetector(
      key: ValueKey('walking-route-place-${place.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePlace(place),
      child: Container(
        key: selected
            ? ValueKey('walking-route-stop-${stopIndex + 1}')
            : ValueKey('walking-route-category-${place.id}'),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                )
              : null,
          color: selected ? null : color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: (selected ? const Color(0xFFEC4899) : color).withValues(
                alpha: 0.4,
              ),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: selected
              ? Text(
                  '${stopIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Icon(
                  _iconForCategory(place.category),
                  color: Colors.white,
                  size: 19,
                ),
        ),
      ),
    );
  }

  Color _colorForCategory(String category) {
    switch (category.trim().toLowerCase()) {
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
      default:
        return AppColors.accent;
    }
  }

  IconData _iconForCategory(String category) {
    switch (category.trim().toLowerCase()) {
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
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeProvider = context.watch<PlaceProvider>();
    final governorates = context.watch<GovernorateProvider>();
    final activeGovernorate =
        EgyptGovernorate.byId[EgyptGovernorate.normalizeId(
          governorates.activeGovernorate,
        )] ??
        EgyptGovernorate.byId['alexandria']!;
    final places = _sortedPlaces(placeProvider.allPlaces, activeGovernorate);
    final origin = _routeOrigin(activeGovernorate);
    final distanceMeters = _routeDistanceMeters(activeGovernorate);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text(
          'Walking Route',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _clear,
              child: Text(
                'Clear',
                style: TextStyle(
                  color: context.textPri,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              key: const ValueKey('walking-routes-governorate-chips'),
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final id in const ['alexandria', 'cairo', 'luxor'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: ValueKey('walking-routes-governorate-$id'),
                      label: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? EgyptGovernorate.byId[id]!.nameAr
                            : EgyptGovernorate.byId[id]!.nameEn,
                      ),
                      selected: activeGovernorate.id == id,
                      onSelected: (selected) {
                        if (selected) _selectGovernorate(id);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      activeGovernorate.centerLat,
                      activeGovernorate.centerLng,
                    ),
                    initialZoom: activeGovernorate.defaultZoom,
                    onMapReady: () => _mapReady = true,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.alsaba.egyptlore',
                      maxZoom: 19,
                    ),
                    if (_selected.isNotEmpty)
                      PolylineLayer(
                        key: const ValueKey('walking-route-polyline-layer'),
                        polylines: [
                          Polyline(
                            points: _routePoints.length > 1
                                ? _routePoints
                                : [
                                    origin,
                                    ..._selected.map(
                                      (place) => LatLng(place.lat, place.lng),
                                    ),
                                  ],
                            color: const Color(0xFF14B8A6),
                            strokeWidth: 4,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: origin,
                          width: 70,
                          height: 34,
                          child: Container(
                            key: const ValueKey('walking-route-origin'),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
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
                        for (final place in places)
                          Marker(
                            point: LatLng(place.lat, place.lng),
                            width: 40,
                            height: 40,
                            child: _placeMarker(
                              place,
                              _selected.indexWhere(
                                (stop) => stop.id == place.id,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_selected.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _RouteSummary(
                      distanceKm: distanceMeters / 1000,
                      minutes: MapRouteService.walkingMinutes(distanceMeters),
                      stopCount: _selected.length,
                      onAutoSort: () => _autoSortByNearest(activeGovernorate),
                      routeLoading: _routeLoading,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _PlaceSelector(
              places: places,
              selected: _selected,
              onToggle: _togglePlace,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final double distanceKm;
  final int minutes;
  final int stopCount;
  final VoidCallback onAutoSort;
  final bool routeLoading;

  const _RouteSummary({
    required this.distanceKm,
    required this.minutes,
    required this.stopCount,
    required this.onAutoSort,
    this.routeLoading = false,
  });

  String _formatTime(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: routeLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.directions_walk_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('tour_stops_count', {'n': '$stopCount'}),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km · ${_formatTime(minutes)}',
                  key: const ValueKey('walking-route-distance'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
            onPressed: onAutoSort,
            tooltip: 'Optimize order',
          ),
        ],
      ),
    );
  }
}

class _PlaceSelector extends StatelessWidget {
  final List<PlaceModel> places;
  final List<PlaceModel> selected;
  final ValueChanged<PlaceModel> onToggle;

  const _PlaceSelector({
    required this.places,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                'Pick places',
                style: TextStyle(
                  color: context.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${selected.length} / 5',
                style: TextStyle(
                  color: context.textSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('walking-route-place-list'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: places.length,
            itemBuilder: (context, i) {
              final p = places[i];
              final isSelected = selected.any((s) => s.id == p.id);
              final orderIdx = isSelected
                  ? selected.indexWhere((s) => s.id == p.id) + 1
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('walking-route-picker-${p.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onToggle(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : context.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : context.textSec.withValues(alpha: 0.12),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFEC4899),
                                        Color(0xFF8B5CF6),
                                      ],
                                    )
                                  : null,
                              color: isSelected ? null : context.bgAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isSelected
                                  ? Text(
                                      '$orderIdx',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : Icon(
                                      Icons.add_rounded,
                                      color: context.textSec,
                                      size: 18,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.localizedName(
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textPri,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  p.category,
                                  style: TextStyle(
                                    color: context.textSec,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? AppColors.primary
                                : context.textSec,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
