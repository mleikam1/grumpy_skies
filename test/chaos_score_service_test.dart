import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/chaos_score_service.dart';

void main() {
  test('scores calm weather in the calm band', () {
    final score = ChaosScoreService.evaluate(_weatherBundle());

    expect(score.value, inInclusiveRange(0, 20));
    expect(score.label, 'Calm');
    expect(score.explanation, 'Quiet signals nearby');
  });

  test('scores high precipitation odds and gusty wind as messy', () {
    final score = ChaosScoreService.evaluate(
      _weatherBundle(
        currentPop: 45,
        hourlyPop: 65,
        windMph: 22,
        condition: 'Light Rain',
        weatherId: 500,
        minutes: List.generate(
          30,
          (index) => MinutePrecipitation(
            time: DateTime.utc(2026, 6, 21, 12, index),
            precipitation: 0.002,
          ),
        ),
      ),
    );

    expect(score.value, inInclusiveRange(41, 65));
    expect(score.label, 'Messy');
  });

  test('scores thunderstorms with alerts as certified chaos', () {
    final score = ChaosScoreService.evaluate(
      _weatherBundle(
        condition: 'Thunderstorm',
        weatherId: 201,
        windMph: 32,
        gustMph: 44,
        rainLastHour: 0.3,
        alerts: const [
          WeatherAlert(
            senderName: 'Weather authority',
            event: 'Severe Thunderstorm Warning',
            description: 'Take shelter.',
          ),
        ],
      ),
    );

    expect(score.value, inInclusiveRange(86, 100));
    expect(score.label, 'Certified chaos');
    expect(score.explanation, 'Thunderstorm signals nearby');
  });
}

WeatherBundle _weatherBundle({
  String condition = 'Clear',
  int weatherId = 800,
  int currentPop = 5,
  int hourlyPop = 8,
  double windMph = 5,
  double? gustMph,
  double rainLastHour = 0,
  List<MinutePrecipitation> minutes = const [],
  List<WeatherAlert> alerts = const [],
}) {
  final now = DateTime.utc(2026, 6, 21, 12);
  final current = CurrentWeather(
    locationName: 'Test City',
    temperatureC: (72 - 32) * 5 / 9,
    condition: condition,
    feelsLikeC: (72 - 32) * 5 / 9,
    windKph: windMph * 1.609344,
    windDirection: 'SW',
    humidity: 55,
    precipitationChance: currentPop,
    aqi: 42,
    sunrise: DateTime.utc(2026, 6, 21, 6),
    sunset: DateTime.utc(2026, 6, 21, 20),
    moonrise: DateTime.utc(2026, 6, 21, 22),
    moonset: DateTime.utc(2026, 6, 22, 6),
    uvIndex: 5,
    lastUpdated: now,
    windGustKph: gustMph == null ? null : gustMph * 1.609344,
    rainLastHour: rainLastHour,
    weatherId: weatherId,
  );

  return WeatherBundle(
    current: current,
    hourly: List.generate(
      12,
      (index) => HourlyForecast(
        time: now.add(Duration(hours: index)),
        temperatureC: (72 - 32) * 5 / 9,
        condition: condition,
        precipitationChance: hourlyPop,
        weatherId: weatherId,
      ),
    ),
    daily: const [],
    minutePrecipitation: minutes,
    alerts: alerts,
  );
}
