import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_grid.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_strip.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

import 'helpers/daymaker_test_helpers.dart';

void main() {
  Widget buildSubject() {
    const repository = FakeWeatherRepository();
    final locationController = WeatherLocationController(
      repository: repository,
      initialLocation: buildTestWeatherLocation(),
    );

    return MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: repository),
        ChangeNotifierProvider<WeatherLocationController>.value(
          value: locationController,
        ),
      ],
      child: MaterialApp(
        theme: DMTheme.light,
        home: const ForecastScreen(
          weatherRepository: repository,
        ),
      ),
    );
  }

  testWidgets('ForecastScreen renders DayMaker dashboard at 390x844',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo City'), findsOneWidget);
    expect(find.text('Partly Cloudy'), findsWidgets);
    expect(find.text('72°F'), findsOneWidget);
    expect(find.text('Last updated 10 min ago'), findsOneWidget);
    expect(find.text('Karen'), findsOneWidget);
    expect(find.text('ROAST QUEEN'), findsOneWidget);
    expect(
      find.text('It’s 72°F and somehow still making a scene.'),
      findsOneWidget,
    );
    expect(find.text('38% rain'), findsWidgets);
    expect(find.text('82 Moderate'), findsWidgets);
    expect(find.text('74° Comfortable'), findsOneWidget);
    expect(find.text('7-day forecast'), findsOneWidget);
    await tester.ensureVisible(find.text('Weather data © OpenWeather'));
    expect(find.text('Weather data © OpenWeather'), findsOneWidget);
    expect(find.bySemanticsLabel('Show a new weather roast'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Share current weather roast'), findsOneWidget);
  });

  testWidgets('ForecastScreen centers usable web layout at expanded width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo City'), findsOneWidget);
    expect(find.text('Hourly'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('forecast carousels render 12 hourly and 7 daily cards',
      (tester) async {
    tester.view.physicalSize = const Size(2200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final reference = DateTime(2026, 6, 21, 12, 30);
    final hourly = List.generate(
      12,
      (index) => HourlyForecast(
        time: DateTime(2026, 6, 21, 12 + index),
        temperatureC: (76 + index - 32) * 5 / 9,
        condition: 'Clear',
        precipitationChance: index * 3,
        weatherIcon: '01d',
        weatherMain: 'Clear',
        weatherId: 800,
      ),
    );
    final daily = List.generate(
      7,
      (index) => DailyForecast(
        date: DateTime(2026, 6, 21 + index),
        minTempC: (60 + index - 32) * 5 / 9,
        maxTempC: (80 + index - 32) * 5 / 9,
        condition: 'Broken Clouds',
        precipitationChance: index * 5,
        weatherIcon: '04d',
        weatherMain: 'Clouds',
        weatherId: 803,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 1800,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ForecastHourlyStrip(
                    hourly: hourly,
                    referenceTime: reference,
                  ),
                  ForecastDailyGrid(
                    daily: daily,
                    referenceTime: reference,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now'), findsOneWidget);
    expect(find.text('1 PM'), findsOneWidget);
    expect(find.textContaining('rain'), findsNWidgets(12));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.textContaining('° / '), findsNWidgets(7));
  });

  testWidgets('ForecastScreen passes selected coordinates to weather fetch',
      (tester) async {
    final repository = _RecordingWeatherRepository();
    final location = WeatherLocation(
      name: 'Actual Place',
      state: 'IL',
      country: 'US',
      latitude: 12.3456,
      longitude: -98.7654,
      source: WeatherLocationSource.device,
      updatedAt: DateTime(2026, 6, 19, 9),
    );
    final locationController = WeatherLocationController(
      repository: repository,
      initialLocation: location,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: repository),
          ChangeNotifierProvider<WeatherLocationController>.value(
            value: locationController,
          ),
        ],
        child: MaterialApp(
          theme: DMTheme.light,
          home: ForecastScreen(weatherRepository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.lastLatitude, closeTo(12.3456, 0.0001));
    expect(repository.lastLongitude, closeTo(-98.7654, 0.0001));
    expect(find.text('Actual Place'), findsOneWidget);
  });

  testWidgets('ForecastScreen shows first-run location prompt without weather',
      (tester) async {
    const repository = FakeWeatherRepository();
    final locationController = WeatherLocationController(
      repository: repository,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: repository),
          ChangeNotifierProvider<WeatherLocationController>.value(
            value: locationController,
          ),
        ],
        child: MaterialApp(
          theme: DMTheme.light,
          home: const ForecastScreen(weatherRepository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Your local sky, not San Francisco.'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
    expect(find.text('Demo City'), findsNothing);
    expect(find.text('72°F'), findsNothing);
  });

  testWidgets('ForecastScreen does not show raw socket errors', (tester) async {
    const repository = _FailingWeatherRepository();
    final locationController = WeatherLocationController(
      repository: repository,
      initialLocation: buildTestWeatherLocation(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: repository),
          ChangeNotifierProvider<WeatherLocationController>.value(
            value: locationController,
          ),
        ],
        child: MaterialApp(
          theme: DMTheme.light,
          home: const ForecastScreen(weatherRepository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forecast unavailable'), findsOneWidget);
    expect(
      find.text(
          'Could not reach the local weather service. Make sure the Firebase emulator is running.'),
      findsOneWidget,
    );
    expect(find.textContaining('SocketConnection'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);
  });
}

class _RecordingWeatherRepository extends WeatherRepository {
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    return _snapshot('Actual Place, IL, US');
  }

  @override
  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
    LocationCandidate? location,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    return WeatherBundle.fromSnapshot(
      _snapshot(location?.displayName ?? 'Actual Place, IL, US'),
    );
  }

  @override
  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  }) async {
    return const [];
  }

  WeatherSnapshot _snapshot(String locationName) {
    final observedAt = DateTime.now();
    return WeatherSnapshot(
      id: 'actual-place',
      locationName: locationName,
      condition: 'Clear',
      temperatureF: 70,
      feelsLikeF: 70,
      windMph: 5,
      windDirection: 'W',
      humidityPercent: 45,
      rainChancePercent: 10,
      aqi: 12,
      aqiCategory: 'Good',
      uvIndex: 3,
      uvCategory: 'Moderate',
      chaosMeterPercent: 20,
      observedAt: observedAt,
      hourly: [
        ForecastHour(
          time: observedAt,
          temperatureF: 70,
          condition: 'Clear',
          rainChancePercent: 10,
        ),
      ],
      daily: [
        ForecastDay(
          date: observedAt,
          lowF: 64,
          highF: 72,
          condition: 'Clear',
          rainChancePercent: 10,
        ),
      ],
      metrics: const [],
    );
  }
}

class _FailingWeatherRepository extends WeatherRepository {
  const _FailingWeatherRepository();

  @override
  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    throw const OpenWeatherBackendException(
      'Could not reach the local weather service. Make sure the Firebase emulator is running.',
    );
  }

  @override
  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
    LocationCandidate? location,
  }) async {
    throw const OpenWeatherBackendException(
      'Could not reach the local weather service. Make sure the Firebase emulator is running.',
    );
  }

  @override
  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  }) async {
    return const [];
  }
}
