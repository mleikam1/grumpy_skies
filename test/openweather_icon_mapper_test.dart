import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/core/weather/openweather_icon_mapper.dart';

void main() {
  test('missing sun events do not manufacture night and provider code wins',
      () {
    final missing = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    expect(
        OpenWeatherIconMapper.resolveIsDay(
          forecastTime: DateTime.utc(2026, 10, 9, 12),
          sunrise: missing,
          sunset: missing,
        ),
        isNull);
    expect(
        OpenWeatherIconMapper.resolveIsDay(
          openWeatherIconCode: '01d',
          forecastTime: DateTime.utc(2026, 10, 9, 12),
          sunrise: missing,
          sunset: missing,
        ),
        isTrue);
  });
  test('future hours never reuse today solar events', () {
    expect(
      OpenWeatherIconMapper.resolveIsDay(
        forecastTime: DateTime.utc(2026, 6, 22, 12),
        forecastLocalTime: DateTime.utc(2026, 6, 22, 7),
        sunrise: DateTime.utc(2026, 6, 21, 11),
        sunset: DateTime.utc(2026, 6, 22, 1),
      ),
      isNull,
    );
  });

  test('selected-local calendar handles sun events across UTC midnight', () {
    expect(
      OpenWeatherIconMapper.resolveIsDay(
        forecastTime: DateTime.utc(2026, 6, 22, 1),
        forecastLocalTime: DateTime.utc(2026, 6, 22, 11),
        sunrise: DateTime.utc(2026, 6, 21, 20),
        sunset: DateTime.utc(2026, 6, 22, 8),
      ),
      isTrue,
    );
    expect(
      OpenWeatherIconMapper.resolveIsDay(
        forecastTime: DateTime.utc(2026, 6, 22, 11),
        forecastLocalTime: DateTime.utc(2026, 6, 22, 21),
        sunrise: DateTime.utc(2026, 6, 21, 20),
        sunset: DateTime.utc(2026, 6, 22, 8),
      ),
      isFalse,
    );
  });

  test('provider hour day/night wins over phone time and another day events',
      () {
    expect(
      OpenWeatherIconMapper.map(
        conditionId: 801,
        openWeatherIconCode: '02n',
        forecastTime: DateTime.utc(2026, 6, 30, 17),
        forecastLocalTime: DateTime.utc(2026, 6, 30, 12),
        sunrise: DateTime.utc(2026, 6, 21, 6),
        sunset: DateTime.utc(2026, 6, 21, 20),
      ),
      'partly-cloudy-night',
    );
  });

  test('unknown ids are not passed through a WMO mapper or made sunny', () {
    expect(OpenWeatherIconMapper.map(conditionId: 0), 'not-available');
    expect(OpenWeatherIconMapper.map(conditionId: 63), 'not-available');
    expect(OpenWeatherIconMapper.map(conditionId: 9999), 'not-available');
    expect(OpenWeatherIconMapper.resolveIsDay(openWeatherIconCode: 'invalid'),
        isNull);
    expect(OpenWeatherIconMapper.map(conditionId: 801), 'cloudy');
  });

  test('all common OpenWeather weather families remain distinct', () {
    const cases = <int, String>{
      200: 'thunderstorms',
      300: 'drizzle',
      501: 'rain',
      600: 'snow',
      611: 'sleet',
      701: 'fog',
      711: 'smoke',
      721: 'haze',
      741: 'fog',
      761: 'dust',
      771: 'wind',
      781: 'tornado',
      803: 'cloudy',
      804: 'overcast',
    };
    for (final entry in cases.entries) {
      expect(OpenWeatherIconMapper.map(conditionId: entry.key), entry.value);
    }
  });

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
        'fog',
      );

      expect(
        OpenWeatherIconMapper.map(conditionDescription: 'Mystery weather'),
        OpenWeatherIconMapper.fallbackSlug,
      );
    });
  });
}
