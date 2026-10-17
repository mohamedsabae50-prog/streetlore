import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/city_coordinates.dart';

class WeatherData {
  static const _cacheKey = 'weather_payload_v1';
  static const cacheTtl = Duration(minutes: 30);

  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double precipitation;
  final int precipitationProbability;
  final int cloudCover;
  final int weatherCode;
  final bool isDay;
  final String conditionKey;
  final DateTime fetchedAt;

  const WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.precipitation,
    required this.precipitationProbability,
    required this.cloudCover,
    required this.weatherCode,
    required this.isDay,
    required this.conditionKey,
    required this.fetchedAt,
  });

  String get iconCode => 'wmo_$weatherCode';

  Map<String, dynamic> toJson() => {
    'tempC': tempC,
    'feelsLikeC': feelsLikeC,
    'humidity': humidity,
    'precipitation': precipitation,
    'precipitationProbability': precipitationProbability,
    'cloudCover': cloudCover,
    'weatherCode': weatherCode,
    'isDay': isDay,
    'conditionKey': conditionKey,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    tempC: (json['tempC'] as num).toDouble(),
    feelsLikeC: (json['feelsLikeC'] as num).toDouble(),
    humidity: (json['humidity'] as num).toInt(),
    precipitation: (json['precipitation'] as num).toDouble(),
    precipitationProbability: (json['precipitationProbability'] as num)
        .toInt(),
    cloudCover: (json['cloudCover'] as num).toInt(),
    weatherCode: (json['weatherCode'] as num).toInt(),
    isDay: json['isDay'] as bool,
    conditionKey: json['conditionKey'] as String,
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  bool _loading = false;
  bool get loading => _loading;

  Future<WeatherData?> fetch({required double lat, required double lng}) async {
    if (_loading) return null;
    _loading = true;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,weather_code,cloud_cover',
        'hourly': 'precipitation_probability',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw StateError('Open-Meteo returned HTTP ${response.statusCode}.');
      }
      final data = parseCurrentWeather(
        jsonDecode(response.body) as Map<String, dynamic>,
        now: DateTime.now(),
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(WeatherData._cacheKey, jsonEncode(data.toJson()));
      } catch (error, stackTrace) {
        debugPrint('WeatherService cache write failed: $error\n$stackTrace');
      }
      return data;
    } catch (error, stackTrace) {
      debugPrint('WeatherService.fetch failed: $error\n$stackTrace');
      return null;
    } finally {
      _loading = false;
    }
  }

  Future<WeatherData?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(WeatherData._cacheKey);
      if (raw == null) return null;
      return WeatherData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      debugPrint('WeatherService.loadCached failed: $error\n$stackTrace');
      return null;
    }
  }

  bool isCacheFresh(WeatherData data, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(data.fetchedAt) <
      WeatherData.cacheTtl;

  Future<WeatherData?> fetchForDeviceLocation() async {
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (error, stackTrace) {
      debugPrint(
        'WeatherService last-known location failed: $error\n$stackTrace',
      );
    }
    return fetch(
      lat: position?.latitude ?? alexandriaCenterLat,
      lng: position?.longitude ?? alexandriaCenterLng,
    );
  }

  @visibleForTesting
  static WeatherData parseCurrentWeather(
    Map<String, dynamic> json, {
    required DateTime now,
  }) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    final times = (hourly?['time'] as List<dynamic>?) ?? const [];
    final probabilities =
        (hourly?['precipitation_probability'] as List<dynamic>?) ?? const [];
    final currentTime = current['time'] as String;
    final currentHour = currentTime.length >= 13
        ? currentTime.substring(0, 13)
        : currentTime;
    var probability = 0;
    for (
      var index = 0;
      index < times.length && index < probabilities.length;
      index++
    ) {
      final time = times[index].toString();
      if (time.startsWith(currentHour)) {
        probability = (probabilities[index] as num?)?.round() ?? 0;
        break;
      }
    }

    final code = (current['weather_code'] as num).toInt();
    final rain = (current['rain'] as num?)?.toDouble() ?? 0;
    final cloudCover = (current['cloud_cover'] as num?)?.toInt() ?? 0;
    return WeatherData(
      tempC: (current['temperature_2m'] as num).toDouble(),
      feelsLikeC: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      precipitation: (current['precipitation'] as num?)?.toDouble() ?? rain,
      precipitationProbability: probability,
      cloudCover: cloudCover,
      weatherCode: code,
      isDay: (current['is_day'] as num).toInt() == 1,
      conditionKey: _conditionKey(
        code: code,
        cloudCover: cloudCover,
        rain: rain,
        precipitationProbability: probability,
      ),
      fetchedAt: now,
    );
  }

  static String _conditionKey({
    required int code,
    required int cloudCover,
    required double rain,
    required int precipitationProbability,
  }) {
    if (const {95, 96, 99}.contains(code)) return 'weather_thunderstorm';
    if (const {71, 73, 75, 77, 85, 86}.contains(code)) return 'weather_snow';
    if (const {45, 48}.contains(code)) return 'weather_fog';
    if (const {51, 53, 55, 56, 57}.contains(code)) return 'weather_drizzle';
    if (const {61, 63, 65, 66, 67, 80, 81, 82}.contains(code) || rain > 0) {
      return 'weather_rain';
    }
    if (code <= 3 && precipitationProbability >= 40) {
      return 'weather_rain_possible';
    }
    if (cloudCover >= 85 || code == 3) return 'weather_overcast';
    if (cloudCover >= 60 || code == 2) return 'weather_partly_cloudy';
    if (code == 0) return 'weather_clear_sky';
    if (code == 1) return 'weather_mainly_clear';
    if (code == 51 || code == 53 || code == 55) return 'weather_drizzle';
    return 'weather_unknown';
  }
}
