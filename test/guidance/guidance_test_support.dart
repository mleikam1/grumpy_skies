import 'dart:convert';
import 'dart:io';
import 'package:grumpy_skies/features/guidance/domain/guidance.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';

GuidanceCatalog testGuidanceCatalog() => GuidanceCatalog.fromJson(
    jsonDecode(
        File('assets/guidance/wingman_tips.en-US.json').readAsStringSync()),
    jsonDecode(File('assets/guidance/wingman_tip_family_contracts.json')
        .readAsStringSync()));

WeatherBundle guidanceTestBundle(
    {bool alert = false,
    bool stale = false,
    bool missing = false,
    bool heat = false}) {
  final now = ApprovedFixture.now;
  final source = stale
      ? now.subtract(const Duration(hours: 8))
      : ApprovedFixture.observedAt;
  final current = CurrentWeather.fromJson({
    ...ApprovedFixture.weather.current.toJson(),
    'condition': heat ? 'Clear' : 'Light rain',
    'weatherId': heat ? 800 : 500,
    'weatherMain': heat ? 'Clear' : 'Rain',
    'weatherIcon': heat ? '01d' : '10d',
    'temperatureC': heat ? 33.0 : 20.0,
    'feelsLikeC': heat ? 34.0 : 20.0,
    'windKph': 10.0,
    'humidity': 65,
    'sourceUpdatedAt': source.toIso8601String(),
    'lastUpdated': source.toIso8601String(),
  });
  return WeatherBundle(
    current: current,
    location: ApprovedFixture.location,
    forecastSource: 'openweather_onecall_3',
    hourly: missing
        ? []
        : [
            for (var i = 0; i < 12; i++)
              HourlyForecast(
                  time: now.add(Duration(hours: i)),
                  temperatureC: heat ? 33 : 20,
                  condition: heat ? 'Clear' : 'Rain',
                  weatherId: heat
                      ? 800
                      : i < 2
                          ? 500
                          : 800,
                  weatherMain: heat
                      ? 'Clear'
                      : i < 2
                          ? 'Rain'
                          : 'Clear',
                  weatherIcon: heat
                      ? '01d'
                      : i < 2
                          ? '10d'
                          : '01d',
                  precipitationChance: heat
                      ? 0
                      : i < 2
                          ? 70
                          : 10,
                  precipitationChanceKnown: true),
          ],
    daily: missing
        ? []
        : [
            for (var i = 0; i < 7; i++)
              DailyForecast(
                  date: DateTime.utc(2026, 10, 12 + i),
                  minTempC: heat ? 25 : 12,
                  maxTempC: heat ? 34 : 24,
                  condition: heat ? 'Clear' : 'Rain',
                  weatherId: heat ? 800 : 500,
                  weatherMain: heat ? 'Clear' : 'Rain',
                  weatherIcon: heat ? '01d' : '10d',
                  precipitationChance: heat ? 0 : 70,
                  precipitationChanceKnown: true),
          ],
    alertCoverageVerified: true,
    alertsCheckedAt: now,
    alerts: alert
        ? [
            WeatherAlert(
                senderName: 'National Weather Service',
                event: 'Flood Watch',
                start: now.subtract(const Duration(minutes: 10)),
                end: now.add(const Duration(hours: 2)),
                severity: 'Moderate',
                area: 'Synthetic review area',
                description: 'Fixture watch: conditions may support flooding.',
                instructions:
                    'Monitor official updates and follow local guidance.'),
          ]
        : [],
  );
}
