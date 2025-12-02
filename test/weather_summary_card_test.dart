import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/widgets/weather_summary_card.dart';

void main() {
  WeatherBundle buildWeatherBundle(String condition) {
    return WeatherBundle(
      current: CurrentWeather(
        temperatureC: 21.3,
        condition: condition,
        feelsLikeC: 22.0,
        windKph: 12.5,
        humidity: 60,
        lastUpdated: DateTime(2024, 1, 1),
      ),
      hourly: const [],
      daily: const [],
    );
  }

  testWidgets('displays sunny icon for clear conditions', (tester) async {
    final weather = buildWeatherBundle('Sunny');

    await tester.pumpWidget(
      MaterialApp(
        home: WeatherSummaryCard(weather: weather),
      ),
    );

    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.textContaining('Sunny'), findsOneWidget);
  });

  testWidgets('displays rain icon for rainy conditions', (tester) async {
    final weather = buildWeatherBundle('Heavy rain');

    await tester.pumpWidget(
      MaterialApp(
        home: WeatherSummaryCard(weather: weather),
      ),
    );

    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.textContaining('Heavy rain'), findsOneWidget);
  });

  testWidgets('falls back to cloud icon for unknown conditions', (tester) async {
    final weather = buildWeatherBundle('Mystery weather');

    await tester.pumpWidget(
      MaterialApp(
        home: WeatherSummaryCard(weather: weather),
      ),
    );

    expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
    expect(find.textContaining('Mystery weather'), findsOneWidget);
  });
}
