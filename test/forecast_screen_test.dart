import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';

void main() {
  testWidgets('ForecastScreen renders DayMaker dashboard at 390x844',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: DMTheme.light,
        home: const ForecastScreen(
          weatherRepository: FakeWeatherRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('San Francisco'), findsOneWidget);
    expect(find.text('Partly Cloudy'), findsWidgets);
    expect(find.text('72°F'), findsOneWidget);
    expect(find.text('Updated 10 min ago'), findsOneWidget);
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
  });

  testWidgets('ForecastScreen centers usable web layout at expanded width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: DMTheme.light,
        home: const ForecastScreen(
          weatherRepository: FakeWeatherRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('San Francisco'), findsOneWidget);
    expect(find.text('Hourly'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });
}
