import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

import 'helpers/daymaker_test_helpers.dart';

void main() {
  Widget buildSubject({http.Client? httpClient}) {
    const repository = FakeWeatherRepository();
    final locationController = WeatherLocationController(
      repository: repository,
      initialLocation: buildTestWeatherLocation(),
    );

    return MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: repository),
        Provider<OpenWeatherBackendClient>.value(
          value: OpenWeatherBackendClient(
            baseUrl: 'https://example.com/api',
            httpClient: httpClient ?? _healthyRadarClient(),
          ),
        ),
        ChangeNotifierProvider<WeatherLocationController>.value(
          value: locationController,
        ),
      ],
      child: MaterialApp(
        theme: DMTheme.light,
        home: const RadarScreen(),
      ),
    );
  }

  testWidgets('RadarScreen renders compact DayMaker radar shell',
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
    expect(find.text('Radar'), findsWidgets);
    expect(find.text('Demo City, US'), findsWidgets);
    expect(find.text('US forecast radar'), findsWidgets);
    expect(find.text('FutureCast'), findsOneWidget);
    expect(find.text('Latest'), findsWidgets);
    expect(find.text('Radar product'), findsOneWidget);
    expect(find.text('Selected frame'), findsOneWidget);
    expect(find.text('Map center'), findsOneWidget);
  });

  testWidgets('RadarScreen keeps controls and alert panel available on web',
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
    expect(find.bySemanticsLabel('Zoom in'), findsOneWidget);
    expect(find.bySemanticsLabel('Use current location'), findsOneWidget);
    expect(find.bySemanticsLabel('Radar layers'), findsOneWidget);
    expect(find.text('Radar product'), findsOneWidget);
    expect(find.text('Selected frame'), findsOneWidget);
    expect(find.text('Map center'), findsOneWidget);
  });

  testWidgets('RadarScreen shows one clean unavailable state for tile fallback',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildSubject(
        httpClient: MockClient((_) async {
          return http.Response(
            '',
            200,
            headers: {
              'content-type': 'image/png',
              'x-grumpy-skies-tile-fallback': 'openweather_radar_access_denied',
            },
          );
        }),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Radar temporarily unavailable. The base map is still usable.'),
      findsOneWidget,
    );
  });
}

http.Client _healthyRadarClient() {
  return MockClient((_) async {
    return http.Response('', 200, headers: {'content-type': 'image/png'});
  });
}
