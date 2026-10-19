import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/locale_provider.dart';
import '../../logic/place_provider.dart';
import '../services/weather_service.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('streetlore/widget');
  static const _prefsNamespace = 'streetlore_widget_v1';

  /// Deterministic place-of-day selection and write to shared storage
  /// for the native Android AppWidget to read. Also triggers a platform
  /// update via MethodChannel when available.
  static Future<void> updateWidgetData(BuildContext context) async {
    try {
      final placeProvider = Provider.of<PlaceProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );
      final places = placeProvider.places;
      if (places.isEmpty) return;
      final now = DateTime.now().toUtc();
      final days = now.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
      final idx = days % places.length;
      final place = places[idx];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsNamespace.locale',
        localeProvider.locale.languageCode,
      );
      await prefs.setString('$_prefsNamespace.place_id', place.id);
      await prefs.setString('$_prefsNamespace.place_title_en', place.nameEn);
      await prefs.setString(
        '$_prefsNamespace.place_title_ar',
        place.nameAr ?? place.nameEn,
      );
      await prefs.setString(
        '$_prefsNamespace.place_snippet_en',
        place.descriptionEn,
      );
      await prefs.setString(
        '$_prefsNamespace.place_snippet_ar',
        place.descriptionAr ?? place.descriptionEn,
      );

      final weather = await WeatherService.instance.loadCached();
      if (weather != null) {
        await prefs.setString(
          '$_prefsNamespace.weather_temp_c',
          weather.tempC.toString(),
        );
        await prefs.setString(
          '$_prefsNamespace.weather_condition',
          weather.conditionKey,
        );
        await prefs.setString(
          '$_prefsNamespace.weather_fetched_at',
          weather.fetchedAt.toIso8601String(),
        );
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('update');
      }
    } catch (e) {
      debugPrint('WidgetSyncService.updateWidgetData failed: $e');
    }
  }
}
