import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/place_provider.dart';
import '../../presentation/screens/place_details_screen.dart';

class WidgetDeepLinkService {
  WidgetDeepLinkService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static String? _pendingPlaceId;
  static bool _navigationInProgress = false;

  static bool handleUri(Uri uri) {
    if (uri.scheme != 'streetlore' || uri.host != 'place') return false;
    final placeId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (placeId.isEmpty) return true;
    _pendingPlaceId = placeId;
    unawaited(openPendingPlace());
    return true;
  }

  static Future<void> openPendingPlace() async {
    final placeId = _pendingPlaceId;
    final context = navigatorKey.currentContext;
    if (placeId == null || context == null || _navigationInProgress) return;

    _navigationInProgress = true;
    try {
      final places = context.read<PlaceProvider>();
      var place = places.places.where((item) => item.id == placeId).firstOrNull;
      if (place == null) {
        await places.loadPlaces(force: true);
        place = places.places.where((item) => item.id == placeId).firstOrNull;
      }
      if (place == null || !context.mounted) {
        debugPrint('Widget deep link refers to unknown place: $placeId');
        _pendingPlaceId = null;
        return;
      }

      _pendingPlaceId = null;
      await navigatorKey.currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailsScreen(place: place!),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not open widget place link: $error\n$stackTrace');
    } finally {
      _navigationInProgress = false;
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
