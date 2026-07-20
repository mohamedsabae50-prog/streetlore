import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double windSpeed;
  final String condition;
  final String description;
  final String iconCode;
  final DateTime fetchedAt;

  const WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.description,
    required this.iconCode,
    required this.fetchedAt,
  });
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  WeatherData? _cached;
  bool _loading = false;

  WeatherData? get cached => _cached;
  bool get loading => _loading;

  String _describeIcon(String code) {
    if (code == '01d' || code == '01n') return 'Clear sky';
    if (code == '02d' || code == '02n') return 'Few clouds';
    if (code == '03d' || code == '03n') return 'Scattered clouds';
    if (code == '04d' || code == '04n') return 'Broken clouds';
    if (code == '09d' || code == '09n') return 'Shower rain';
    if (code == '10d' || code == '10n') return 'Rain';
    if (code == '11d' || code == '11n') return 'Thunderstorm';
    if (code == '13d' || code == '13n') return 'Snow';
    if (code == '50d' || code == '50n') return 'Mist';
    return 'Unknown';
  }

  Future<WeatherData?> fetch({
    double lat = 31.2001,
    double lng = 29.9187,
  }) async {
    if (_loading) return _cached;
    _loading = true;
    try {
      const apiKey = String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
      if (apiKey.isEmpty) {
        return _mockWeather();
      }
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=$apiKey&units=metric',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('WeatherService: API returned ${res.statusCode}');
        return _cached ?? _mockWeather();
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final main = json['main'] as Map<String, dynamic>;
      final wind = json['wind'] as Map<String, dynamic>? ?? const {};
      final weather = (json['weather'] as List?)?.first as Map<String, dynamic>?;
      if (weather == null) return _mockWeather();
      final data = WeatherData(
        tempC: (main['temp'] as num).toDouble(),
        feelsLikeC: (main['feels_like'] as num).toDouble(),
        humidity: (main['humidity'] as num).toInt(),
        windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0,
        condition: (weather['main'] as String?) ?? 'Clear',
        description: _describeIcon(weather['icon'] as String? ?? '01d'),
        iconCode: (weather['icon'] as String?) ?? '01d',
        fetchedAt: DateTime.now(),
      );
      _cached = data;
      return data;
    } catch (e) {
      debugPrint('WeatherService: failed: $e');
      return _cached ?? _mockWeather();
    } finally {
      _loading = false;
    }
  }

  Future<WeatherData?> fetchForDeviceLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return fetch(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      debugPrint('WeatherService: device location failed: $e');
      return null;
    }
  }

  WeatherData _mockWeather() {
    return WeatherData(
      tempC: 24,
      feelsLikeC: 26,
      humidity: 65,
      windSpeed: 4.2,
      condition: 'Clear',
      description: 'Clear sky',
      iconCode: '01d',
      fetchedAt: DateTime.now(),
    );
  }
}
