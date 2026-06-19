import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  Future<SettingsController> createController(
    InMemorySettingsRepository repository,
  ) async {
    final controller = SettingsController(repository: repository);
    await controller.loadSettings();
    return controller;
  }

  Widget buildProviders({
    required InMemorySettingsRepository repository,
    required SettingsController controller,
    required Widget child,
  }) {
    const weatherRepository = FakeWeatherRepository();
    final locationController = WeatherLocationController(
      repository: weatherRepository,
      initialLocation: _buildSettingsTestLocation(),
    );

    return MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<SettingsRepository>.value(value: repository),
        ChangeNotifierProvider<WeatherLocationController>.value(
          value: locationController,
        ),
        ChangeNotifierProvider<SettingsController>.value(value: controller),
      ],
      child: child,
    );
  }

  Future<void> pumpSettingsScreen(
    WidgetTester tester, {
    required InMemorySettingsRepository repository,
    required SettingsController controller,
  }) async {
    await tester.pumpWidget(
      buildProviders(
        repository: repository,
        controller: controller,
        child: MaterialApp(
          theme: DMTheme.light,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Fahrenheit/Celsius selector updates settings state',
      (tester) async {
    final repository = InMemorySettingsRepository();
    final controller = await createController(repository);

    await pumpSettingsScreen(
      tester,
      repository: repository,
      controller: controller,
    );

    expect(controller.temperatureUnit, TemperatureUnit.fahrenheit);

    await tester.tap(find.text('°C Celsius'));
    await tester.pumpAndSettle();

    final saved = await repository.loadSettings();
    expect(controller.temperatureUnit, TemperatureUnit.celsius);
    expect(saved.temperatureUnit, TemperatureUnit.celsius);
  });

  testWidgets('notification row toggles and persists settings', (tester) async {
    final repository = InMemorySettingsRepository();
    final controller = await createController(repository);

    await pumpSettingsScreen(
      tester,
      repository: repository,
      controller: controller,
    );

    expect(controller.notificationsEnabled, isTrue);
    expect(
      find.bySemanticsLabel('Toggle daily weather notifications'),
      findsWidgets,
    );

    await tester.ensureVisible(find.text('Daily weather nudges'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily weather nudges'));
    await tester.pumpAndSettle();

    final saved = await repository.loadSettings();
    expect(controller.notificationsEnabled, isFalse);
    expect(saved.notificationsEnabled, isFalse);
  });

  testWidgets('About row navigates to /settings/about', (tester) async {
    final repository = InMemorySettingsRepository();
    final controller = await createController(repository);
    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) {
            return buildProviders(
              repository: repository,
              controller: controller,
              child: const SettingsScreen(),
            );
          },
          routes: [
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: DMTheme.light,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    final aboutRow = find.ancestor(
      of: find.text('About DayMaker'),
      matching: find.byType(InkWell),
    );

    await tester.ensureVisible(find.text('About DayMaker'));
    await tester.pumpAndSettle();
    await tester.tap(aboutRow);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.about,
    );
    expect(find.text('Live Data Sources'), findsOneWidget);
    expect(find.text('Weather data © OpenWeather'), findsOneWidget);
    expect(find.text('Version 0.1.0'), findsOneWidget);
  });

  testWidgets('settings layout renders on phone, tablet, and web widths',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      final repository = InMemorySettingsRepository();
      final controller = await createController(repository);

      await pumpSettingsScreen(
        tester,
        repository: repository,
        controller: controller,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Customize your experience.'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

WeatherLocation _buildSettingsTestLocation() {
  return WeatherLocation(
    name: 'Demo City',
    country: 'US',
    latitude: 41.8781,
    longitude: -87.6298,
    source: WeatherLocationSource.manual,
    updatedAt: DateTime(2026, 6, 14, 9),
  );
}
