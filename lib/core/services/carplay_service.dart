import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'google_maps_search.dart';

import '../../data/models/place_model.dart';
import '../../data/models/itinerary_model.dart';

class CarPlayPlaceSection {
  final String id;
  final String title;
  final List<PlaceModel> places;
  final List<ItineraryModel> tours;

  const CarPlayPlaceSection({
    required this.id,
    required this.title,
    required this.places,
    this.tours = const [],
  });
}

class CarPlayService {
  CarPlayService._();

  static final CarPlayService instance = CarPlayService._();

  static const defaultLatitude = 31.2001;
  static const defaultLongitude = 29.9187;

  List<PlaceModel> _places = const [];
  List<PlaceModel> _savedPlaces = const [];
  List<ItineraryModel> _tours = const [];
  double _latitude = defaultLatitude;
  double _longitude = defaultLongitude;
  FlutterCarplay? _carPlay;
  FlutterAndroidAuto? _androidAuto;
  bool _initialized = false;

  List<CarPlayPlaceSection> buildSections({
    List<PlaceModel>? places,
    List<PlaceModel>? savedPlaces,
    List<ItineraryModel>? tours,
    double? latitude,
    double? longitude,
  }) {
    final alexandriaPlaces = (places ?? _places)
        .where((place) => place.governorate == 'alexandria')
        .toList(growable: false);
    final userLatitude = latitude ?? _latitude;
    final userLongitude = longitude ?? _longitude;
    final alexandriaTours = (tours ?? _tours)
        .where((tour) => tour.governorate == 'alexandria')
        .toList(growable: false);
    final foodAndCafes = alexandriaPlaces
        .where((place) => place.category == 'Food' || place.category == 'Cafe')
        .toList(growable: false);
    final shopping = alexandriaPlaces
        .where((place) => place.category == 'Shopping')
        .toList(growable: false);
    final savedIds = (savedPlaces ?? _savedPlaces)
        .map((place) => place.id)
        .toSet();
    final labels = _sectionLabels;

    return [
      CarPlayPlaceSection(
        id: 'nearby',
        title: labels.$1,
        places: [...alexandriaPlaces]
          ..sort(
            (a, b) => _distanceMeters(
              a,
              userLatitude,
              userLongitude,
            ).compareTo(_distanceMeters(b, userLatitude, userLongitude)),
          ),
        tours: alexandriaTours
            .where(
              (tour) => tour.places.any(
                (place) =>
                    place.lat.isFinite &&
                    place.lng.isFinite &&
                    (place.lat != 0 || place.lng != 0),
              ),
            )
            .toList(growable: false),
      ),
      CarPlayPlaceSection(
        id: 'food_cafes',
        title: labels.$2,
        places: foodAndCafes,
      ),
      CarPlayPlaceSection(id: 'shopping', title: labels.$3, places: shopping),
      CarPlayPlaceSection(
        id: 'saved',
        title: labels.$4,
        places: alexandriaPlaces
            .where((place) => savedIds.contains(place.id))
            .toList(growable: false),
      ),
    ];
  }

  (String, String, String, String) get _sectionLabels =>
      PlatformDispatcher.instance.locale.languageCode == 'ar'
      ? ('الأقرب إليك', 'مطاعم وكافيهات', 'تسوق ومولات', 'المحفوظات')
      : ('Nearby Gems', 'Food & Cafes', 'Shopping', 'Saved');

  Uri navigationUri(PlaceModel place, {TargetPlatform? platform}) {
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return Uri.https('maps.apple.com', '/', {
          'q':
              '${cleanPlaceName(place.nameEn)}, '
              '${place.governorate}, Egypt',
        });
      case TargetPlatform.android:
        return googleMapsSearchUri(place);
      default:
        return googleMapsSearchUri(place);
    }
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        _carPlay = FlutterCarplay()
          ..addListenerOnConnectionChange(_onConnectionChanged);
        break;
      case TargetPlatform.android:
        _androidAuto = FlutterAndroidAuto()
          ..addListenerOnConnectionChange(_onConnectionChanged);
        if (FlutterAndroidAuto.connectionStatus ==
            ConnectionStatusTypes.connected.name) {
          await _installRoot();
        }
        break;
      default:
        return;
    }
    if (_carPlay != null) await _installRoot();
  }

  void syncPlaces({
    required List<PlaceModel> places,
    List<PlaceModel> savedPlaces = const [],
    List<ItineraryModel> tours = const [],
  }) {
    _places = List.unmodifiable(places);
    _savedPlaces = List.unmodifiable(savedPlaces);
    _tours = List.unmodifiable(tours);
    if (_initialized) unawaited(_installRoot());
  }

  void updateLocation(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Location must contain valid latitude/longitude.');
    }
    _latitude = latitude;
    _longitude = longitude;
    if (_initialized) unawaited(_installRoot());
  }

  void _onConnectionChanged(ConnectionStatusTypes status) {
    if (status == ConnectionStatusTypes.connected) {
      unawaited(_installRoot());
    }
  }

  Future<void> _installRoot() async {
    try {
      final sections = buildSections();
      final carPlay = _carPlay;
      if (carPlay != null) {
        await FlutterCarplay.setRootTemplate(
          rootTemplate: CPTabBarTemplate(
            templates: sections.map(_carPlayTemplate).toList(growable: false),
          ),
        );
      } else if (_androidAuto != null &&
          FlutterAndroidAuto.connectionStatus ==
              ConnectionStatusTypes.connected.name) {
        await FlutterAndroidAuto.setRootTemplate(
          template: AATabBarTemplate(
            tabs: sections.map(_androidAutoTemplate).toList(growable: false),
          ),
        );
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'CarPlayService: native template update failed: $error\n$stackTrace',
      );
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'CarPlayService: native car plugin unavailable: $error\n$stackTrace',
      );
    } on StateError catch (error, stackTrace) {
      debugPrint(
        'CarPlayService: native car host is not ready: $error\n$stackTrace',
      );
    }
  }

  CPListTemplate _carPlayTemplate(CarPlayPlaceSection section) {
    final listSections = <CPListSection>[
      CPListSection(
        items: section.places
            .take(20)
            .map(
              (place) => CPListItem(
                text: place.nameEn,
                detailText:
                    '${place.category} · ${place.rating.toStringAsFixed(1)} ★',
                onPress: (complete, _) async {
                  try {
                    await FlutterCarplay.push(
                      template: _placeInformationTemplate(place),
                    );
                  } finally {
                    complete();
                  }
                },
              ),
            )
            .toList(growable: false),
      ),
    ];
    if (section.id == 'nearby' && section.tours.isNotEmpty) {
      listSections.add(
        CPListSection(
          header: 'Alexandria Tours',
          items: section.tours
              .take(8)
              .map(_carPlayTourItem)
              .toList(growable: false),
        ),
      );
    }
    return CPListTemplate(
      title: section.title,
      tabTitle: section.title,
      sections: listSections,
    );
  }

  CPListItem _carPlayTourItem(ItineraryModel tour) {
    return CPListItem(
      text: tour.title,
      detailText: tour.duration,
      onPress: (complete, _) async {
        try {
          final firstStop = tour.places.first;
          await FlutterCarplay.push(
            template: _placeInformationTemplate(firstStop, title: tour.title),
          );
        } finally {
          complete();
        }
      },
    );
  }

  CPInformationTemplate _placeInformationTemplate(
    PlaceModel place, {
    String? title,
  }) {
    return CPInformationTemplate(
      title: title ?? place.nameEn,
      layout: CPInformationTemplateLayout.leading,
      informationItems: [
        CPInformationItem(title: place.category, detail: place.address),
        CPInformationItem(
          title: '${place.rating.toStringAsFixed(1)} ★',
          detail: place.openHours,
        ),
      ],
      actions: [
        CPTextButton(
          title: 'Navigate',
          onPress: () async {
            await openNavigation(place, platform: TargetPlatform.iOS);
          },
        ),
      ],
    );
  }

  AAListTemplate _androidAutoTemplate(CarPlayPlaceSection section) {
    final listSections = <AAListSection>[
      AAListSection(
        items: section.places
            .take(20)
            .map(
              (place) => AAListItem(
                title: place.nameEn,
                subtitle:
                    '${place.category} · ${place.rating.toStringAsFixed(1)} ★',
                onPress: (complete, _) async {
                  try {
                    await openNavigation(
                      place,
                      platform: TargetPlatform.android,
                    );
                  } finally {
                    complete();
                  }
                },
              ),
            )
            .toList(growable: false),
      ),
    ];
    if (section.id == 'nearby' && section.tours.isNotEmpty) {
      listSections.add(
        AAListSection(
          title: 'Alexandria Tours',
          items: section.tours
              .take(8)
              .map(
                (tour) => AAListItem(
                  title: tour.title,
                  subtitle: tour.duration,
                  onPress: (complete, _) async {
                    try {
                      await openNavigation(
                        tour.places.first,
                        platform: TargetPlatform.android,
                      );
                    } finally {
                      complete();
                    }
                  },
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    return AAListTemplate(
      title: section.title,
      tabTitle: section.title,
      sections: listSections,
    );
  }

  Future<bool> openNavigation(
    PlaceModel place, {
    TargetPlatform? platform,
  }) async {
    final uri = navigationUri(place, platform: platform);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('CarPlayService: no navigation app handled $uri');
      }
      return launched;
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'CarPlayService: navigation handoff failed: $error\n$stackTrace',
      );
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'CarPlayService: URL launcher unavailable: $error\n$stackTrace',
      );
      return false;
    }
  }

  static double _distanceMeters(PlaceModel place, double lat, double lng) {
    const earthRadius = 6371000.0;
    final radians = math.pi / 180;
    final firstLat = lat * radians;
    final secondLat = place.lat * radians;
    final deltaLat = (place.lat - lat) * radians;
    final deltaLng = (place.lng - lng) * radians;
    final haversine =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(firstLat) *
            math.cos(secondLat) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return 2 *
        earthRadius *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}
