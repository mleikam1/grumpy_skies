import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grumpy_skies/design/dm_metric_colors.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_sun_times.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_metric_chips.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/open_weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

CurrentWeather _weather(Map<String, dynamic> values) =>
    CurrentWeather.fromJson({
      ...ApprovedFixture.weather.current.toJson(),
      ...values,
    });

void main() {
  for (final dark in [false, true]) {
    testWidgets('hourly provider error grows at 2x ${dark ? 'dark' : 'light'}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const message =
          'Forecast timeline needs OpenWeather One Call API 4.0 access.';
      await tester.pumpWidget(MaterialApp(
          theme: dark ? DMTheme.dark : DMTheme.light,
          home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(18),
                          child: ForecastHourlyStrip(
                              hourly: [], errorMessage: message)))))));
      final paragraph =
          tester.renderObject<RenderParagraph>(find.text(message));
      expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width)));
      expect(tester.takeException(), isNull);
    });
    testWidgets('metric roles meet contrast in ${dark ? 'dark' : 'light'}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: dark ? DMTheme.dark : DMTheme.light,
          home: Builder(builder: (context) {
            for (final tone in DMMetricTone.values) {
              final c = DMMetricColors.of(context, tone);
              double ratio(Color foreground) {
                final a = foreground.computeLuminance(),
                    b = c.surface.computeLuminance();
                return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
              }

              for (final foreground in [
                c.value,
                c.label,
                c.status,
                c.unavailable
              ]) {
                expect(ratio(foreground), greaterThanOrEqualTo(4.5));
              }
              expect(ratio(c.accent), greaterThanOrEqualTo(3));
            }
            return const SizedBox();
          })));
    });
    testWidgets(
        'sun times keep real values and wrap at 2x ${dark ? 'dark' : 'light'}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weather = _weather({
        'humidity': 41,
        'pressureHpa': 1013,
        'visibilityMeters': 10000,
        'uvIndex': 7,
        'uvCategory': 'High',
        'units': 'metric',
        'rainLastHour': 1.2,
        'snowLastHour': .4,
        'sunrise': '2026-10-12T12:22:00Z',
        'sunset': '2026-10-12T23:49:00Z',
      });
      await tester.pumpWidget(MaterialApp(
          theme: dark ? DMTheme.dark : DMTheme.light,
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: ForecastSunTimes(weather: weather)))))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('7:22 AM'), findsOneWidget);
      expect(find.text('6:49 PM'), findsOneWidget);
      expect(find.text('Moonrise'), findsNothing);
      expect(find.text('Moonset'), findsNothing);
      for (final paragraph
          in tester.allRenderObjects.whereType<RenderParagraph>()) {
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      await tester.ensureVisible(find.text('Sunset'));
      expect(tester.takeException(), isNull);
    });
  }

  test('missing provider astronomy and UV remain unavailable after persistence',
      () async {
    final client = OpenWeatherBackendClient(
        baseUrl: 'https://weather.invalid',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'current': {'temp': 72, 'units': 'imperial'},
            }),
            200,
            headers: {'content-type': 'application/json'})));
    final weather = await client.forecast(latitude: 40, longitude: -90);
    final restored = CurrentWeather.fromJson(weather.current.toJson());
    for (final time in [
      restored.sunrise,
      restored.sunset,
      restored.moonrise,
      restored.moonset
    ]) {
      expect(time.millisecondsSinceEpoch, 0);
    }
    expect(restored.uvIndex, -1);
    expect(restored.uvCategory, isEmpty);
    final bundle = await OpenWeatherRepository(client: client).getWeather(
        latitude: 40, longitude: -90, location: ApprovedFixture.location);
    final snapshot = bundle.snapshot!;
    expect(snapshot.aqiCategory, isEmpty);
    expect(snapshot.aqiLabel, isNot(contains('Live')));
  });

  test('snapshot adapter cannot invent sun or moon event times', () {
    final current = CurrentWeather.fromSnapshot(ApprovedFixture.snapshot);
    expect(current.sunrise.millisecondsSinceEpoch, 0);
    expect(current.moonrise.millisecondsSinceEpoch, 0);
  });

  test('visibility preserves imperial miles and metric kilometres', () {
    expect(_weather({'visibilityMeters': 10000}).visibilityLabel, '6.2 mi');
    expect(
        _weather({'visibilityMeters': 10000, 'units': 'metric'})
            .visibilityLabel,
        '10.0 km');
    expect(_weather({}).visibilityLabel, 'Unavailable');
  });

  testWidgets('unsupported AQI and absent rain are explicitly unavailable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
            body: ForecastMetricChips(
                weather: ApprovedFixture.snapshot, rainAvailable: false))));
    expect(find.bySemanticsLabel('AQI, Unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Rain, Unavailable'), findsOneWidget);
    expect(find.textContaining('Not supplied'), findsNothing);
  });
}
