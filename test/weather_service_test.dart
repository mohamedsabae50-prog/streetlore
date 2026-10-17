import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/weather_service.dart';

void main() {
  final now = DateTime(2026, 10, 16, 21);

  test(
    'parses current weather, apparent temperature, and matching hourly rain probability',
    () {
      final weather = WeatherService.parseCurrentWeather({
        'current': {
          'time': '2026-10-16T21:00',
          'temperature_2m': 21,
          'relative_humidity_2m': 68,
          'apparent_temperature': 22.4,
          'is_day': 0,
          'precipitation': 0,
          'rain': 0,
          'weather_code': 0,
          'cloud_cover': 72,
        },
        'hourly': {
          'time': ['2026-10-16T20:00', '2026-10-16T21:00'],
          'precipitation_probability': [15, 60],
        },
      }, now: now);

      expect(weather.tempC, 21);
      expect(weather.feelsLikeC, 22.4);
      expect(weather.humidity, 68);
      expect(weather.isDay, isFalse);
      expect(weather.cloudCover, 72);
      expect(weather.precipitationProbability, 60);
      expect(weather.conditionKey, 'weather_rain_possible');
    },
  );

  test('maps overcast and active rain from WMO weather codes', () {
    final overcast = WeatherService.parseCurrentWeather(
      _response(code: 3, cloudCover: 92),
      now: now,
    );
    final rain = WeatherService.parseCurrentWeather(
      _response(code: 61, cloudCover: 100, rain: 0.2),
      now: now,
    );

    expect(overcast.conditionKey, 'weather_overcast');
    expect(rain.conditionKey, 'weather_rain');
  });

  test('weather payload round-trips and respects its 30-minute TTL', () {
    final weather = WeatherService.parseCurrentWeather(
      _response(code: 3, cloudCover: 92),
      now: now,
    );
    final restored = WeatherData.fromJson(weather.toJson());

    expect(restored.tempC, weather.tempC);
    expect(restored.conditionKey, weather.conditionKey);
    expect(restored.fetchedAt, weather.fetchedAt);
    expect(
      WeatherService.instance.isCacheFresh(
        restored,
        now: now.add(const Duration(minutes: 29)),
      ),
      isTrue,
    );
    expect(
      WeatherService.instance.isCacheFresh(
        restored,
        now: now.add(const Duration(minutes: 31)),
      ),
      isFalse,
    );
  });
}

Map<String, dynamic> _response({
  required int code,
  required int cloudCover,
  double rain = 0,
}) => {
  'current': {
    'time': '2026-10-16T21:00',
    'temperature_2m': 21,
    'relative_humidity_2m': 68,
    'apparent_temperature': 22,
    'is_day': 0,
    'precipitation': rain,
    'rain': rain,
    'weather_code': code,
    'cloud_cover': cloudCover,
  },
  'hourly': {
    'time': ['2026-10-16T21:00'],
    'precipitation_probability': [0],
  },
};
