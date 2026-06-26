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
    expect(find.text('FutureCast'), findsOneWidget);
    expect(find.text('Latest'), findsWidgets);
    expect(find.bySemanticsLabel('Radar legend and info'), findsOneWidget);
    expect(find.text('Radar product'), findsNothing);
    expect(find.text('Selected frame'), findsNothing);
    expect(find.text('Map center'), findsNothing);
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
    expect(find.bySemanticsLabel('Recenter radar map'), findsOneWidget);
    expect(find.bySemanticsLabel('Radar layers'), findsOneWidget);
    expect(find.bySemanticsLabel('Radar legend and info'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Radar legend and info'));
    await tester.pumpAndSettle();

    expect(find.text('US forecast radar'), findsOneWidget);
    expect(find.text('Precipitation legend'), findsOneWidget);
    expect(find.text('Weather data © OpenWeather'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Radar product/API access issue. Check OpenWeather Maps access on the server key.',
      ),
      findsOneWidget,
    );
  });
}

http.Client _healthyRadarClient() {
  return MockClient((_) async {
    return http.Response('', 200, headers: {'content-type': 'image/png'});
  });
}
