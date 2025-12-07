import 'dart:math';

import 'weather_api_service.dart';
import '../models/weather_models.dart';

class DummyWeatherService implements WeatherApiService {
  final _random = Random();

  @override
  Future<WeatherBundle> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final sunrise = DateTime(now.year, now.month, now.day, 6, 45);
    final sunset = DateTime(now.year, now.month, now.day, 19, 30);
    final moonrise = DateTime(now.year, now.month, now.day, 21, 10);
    final moonset = DateTime(now.year, now.month, now.day + 1, 7, 5);

    final current = CurrentWeather(
      temperatureC: 20 + _random.nextInt(15).toDouble(),
      condition: 'Partly Cloudy',
      feelsLikeC: 20 + _random.nextInt(15).toDouble(),
      windKph: 5 + _random.nextInt(20).toDouble(),
      humidity: 40 + _random.nextInt(40),
      precipitationChance: 10 + _random.nextInt(70),
      aqi: 40 + _random.nextInt(120),
      sunrise: sunrise,
      sunset: sunset,
      moonrise: moonrise,
      moonset: moonset,
      uvIndex: 3 + _random.nextDouble() * 6,
      lastUpdated: now,
    );

    final hourly = List.generate(12, (index) {
      final time = now.add(Duration(hours: index));
      return HourlyForecast(
        time: time,
        temperatureC:
            current.temperatureC + _random.nextDouble() * 4 - 2, // +/- 2 degrees
        condition: 'Cloudy',
      );
    });

    final daily = List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      return DailyForecast(
        date: date,
        minTempC: 12 + _random.nextInt(8).toDouble(),
        maxTempC: 22 + _random.nextInt(8).toDouble(),
        condition: index == 2 ? 'Rain' : 'Sunny',
      );
    });

    return WeatherBundle(
      current: current,
      hourly: hourly,
      daily: daily,
    );
  }
}
