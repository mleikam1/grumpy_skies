import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/core/weather/openweather_icon_mapper.dart';

void main() {
  group('OpenWeatherIconMapper', () {
    test('uses OpenWeather icon suffix for clear day and night variants', () {
      expect(
        OpenWeatherIconMapper.map(
          conditionId: 800,
          openWeatherIconCode: '01n',
          conditionMain: 'Clear',
          conditionDescription: 'clear sky',
          forecastTime: DateTime(2026, 6, 21, 12),
          sunrise: DateTime(2026, 6, 21, 6),
          sunset: DateTime(2026, 6, 21, 20),
        ),
        'clear-night',
      );

      expect(
        OpenWeatherIconMapper.map(
          conditionId: 800,
          openWeatherIconCode: '01d',
        ),
        'clear-day',
      );
    });

    test('maps OpenWeather rain and storm condition IDs', () {
      expect(
        OpenWeatherIconMapper.map(
          conditionId: 500,
          openWeatherIconCode: '10d',
          conditionMain: 'Rain',
          conditionDescription: 'light rain',
        ),
        'rain',
      );

      expect(
        OpenWeatherIconMapper.map(
          conditionId: 201,
          openWeatherIconCode: '11n',
          conditionMain: 'Thunderstorm',
          conditionDescription: 'thunderstorm with rain',
        ),
        'thunderstorms',
      );
    });

    test('falls back to sunrise and sunset when icon code is missing', () {
      expect(
        OpenWeatherIconMapper.map(
          conditionId: 804,
          conditionMain: 'Clouds',
          conditionDescription: 'overcast clouds',
          forecastTime: DateTime(2026, 6, 21, 22),
          sunrise: DateTime(2026, 6, 21, 6),
          sunset: DateTime(2026, 6, 21, 20),
        ),
        'overcast-night',
      );
    });

    test('uses OpenWeather icon family when condition ID is unavailable', () {
      expect(
        OpenWeatherIconMapper.map(openWeatherIconCode: '13n'),
        'snow',
      );
    });

    test('falls back to text and then a package-safe default', () {
      expect(
        OpenWeatherIconMapper.map(
          conditionMain: 'Mist',
          conditionDescription: 'mist',
        ),
        'mist',
      );

      expect(
        OpenWeatherIconMapper.map(conditionDescription: 'Mystery weather'),
        OpenWeatherIconMapper.fallbackSlug,
      );
    });
  });
}
