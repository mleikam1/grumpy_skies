import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/widgets/weather_summary_card.dart';

void main() {
  WeatherBundle buildWeatherBundle(String condition) {
    final now = DateTime(2024, 1, 1);

    return WeatherBundle(
      current: CurrentWeather(
        temperatureC: 21.3,
        condition: condition,
        feelsLikeC: 22.0,
        windKph: 12.5,
        humidity: 60,
        precipitationChance: 20,
        aqi: 42,
        sunrise: DateTime(2024, 1, 1, 7),
        sunset: DateTime(2024, 1, 1, 17),
        moonrise: DateTime(2024, 1, 1, 20),
        moonset: DateTime(2024, 1, 2, 8),
        uvIndex: 4.5,
        lastUpdated: now,
      ),
      hourly: const [],
      daily: const [],
    );
  }

  Widget buildSubject(WeatherBundle weather) {
    return ChangeNotifierProvider<SettingsController>(
      create: (_) => SettingsController(),
      child: MaterialApp(
        theme: DMTheme.light,
        home: WeatherSummaryCard(weather: weather),
      ),
    );
  }

  testWidgets('displays sunny icon for clear conditions', (tester) async {
    final weather = buildWeatherBundle('Sunny');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.textContaining('Sunny'), findsOneWidget);
  });

  testWidgets('displays rain icon for rainy conditions', (tester) async {
    final weather = buildWeatherBundle('Heavy rain');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.textContaining('Heavy rain'), findsOneWidget);
  });

  testWidgets('falls back to cloud icon for unknown conditions',
      (tester) async {
    final weather = buildWeatherBundle('Mystery weather');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
    expect(find.textContaining('Mystery weather'), findsOneWidget);
  });
}
