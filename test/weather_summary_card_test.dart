import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';
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

  testWidgets('displays animated icon for clear conditions', (tester) async {
    final weather = buildWeatherBundle('Sunny');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(find.bySemanticsLabel('Sunny'), findsOneWidget);
    expect(find.textContaining('Sunny'), findsOneWidget);
  });

  testWidgets('displays animated icon for rainy conditions', (tester) async {
    final weather = buildWeatherBundle('Heavy rain');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(find.bySemanticsLabel('Heavy rain'), findsOneWidget);
    expect(find.textContaining('Heavy rain'), findsOneWidget);
  });

  testWidgets('keeps unknown conditions renderable with a fallback icon',
      (tester) async {
    final weather = buildWeatherBundle('Mystery weather');

    await tester.pumpWidget(buildSubject(weather));

    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(find.bySemanticsLabel('Mystery weather'), findsOneWidget);
    expect(find.textContaining('Mystery weather'), findsOneWidget);
  });
}
