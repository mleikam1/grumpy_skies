import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app.dart';
import 'package:grumpy_skies/app/daymaker_router.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_timeline.dart';
import 'package:grumpy_skies/features/forecast/models/hourly_timeline.dart';
import 'package:grumpy_skies/features/roasts/controllers/local_roast_controller.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/main.dart' as production;
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

/// Opt-in native profile check of the real entry point and live repositories.
/// No fixture weather, alternate provider, or production configuration change.
/// Run on a supported profile device with RUN_LIVE_FORECAST_PROFILE=true.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_LIVE_FORECAST_PROFILE');
  testWidgets('production hourly timeline live profile and request accounting',
      (tester) async {
    expect(kProfileMode, isTrue,
        reason:
            'This measurement must run in a supported profile environment.');
    production.main();
    await _waitFor(
        tester, () => find.byType(GrumpySkiesApp).evaluate().isNotEmpty);
    final context = tester.element(find.byType(GrumpySkiesApp));
    final locations = context.read<WeatherLocationController>();
    if (locations.selectedLocation == null) {
      const city = String.fromEnvironment('LIVE_PROFILE_CITY',
          defaultValue: 'San Francisco');
      final matches = await locations.searchCity(city);
      expect(matches, isNotEmpty,
          reason: 'Live geocoding must return a real city.');
      await locations.selectLocation(matches.first);
    }
    daymakerRouter.go(AppRoutes.forecast);
    await _waitFor(
        tester, () => locations.currentWeather?.hourly.isNotEmpty == true);
    final loaded = locations.currentWeather!;
    final roasts = context.read<LocalRoastController>();
    final settings = context.read<SettingsController>();
    await _waitFor(tester, () => roasts.ready || roasts.loadError != null);
    expect(roasts.ready, isTrue,
        reason: 'The real bundled roast catalog must finish loading.');
    await tester.pump(const Duration(seconds: 2));
    final strip = find.byType(ForecastHourlyList);
    await tester.ensureVisible(strip);
    await tester.pump(const Duration(milliseconds: 400));
    final seeAll = find.descendant(of: strip, matching: find.text('See all'));
    expect(seeAll, findsOneWidget);
    final before = NetworkCounters.instance.snapshot;

    Future<void> open() async {
      await tester.tap(seeAll);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ForecastHourlyTimeline), findsOneWidget);
    }

    await open();
    // Warm one viewport so asset decode is distinguished from measured scrolling.
    await tester.pump(const Duration(seconds: 2));
    final plannedCards = roasts.selectHourlyTimeline(
      persona: settings.selectedPersonaId,
      bundle: loaded,
      hours: forecastTimelineHours(loaded.hourly, DateTime.now()),
      unit: settings.temperatureUnit,
    );
    final builtCards = find.byWidgetPredicate((widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('hourly-roast-'));
    final builtCardCount = builtCards.evaluate().length;
    final roastContext = WeatherRoastContext.fromWeatherBundle(loaded,
        scope: RoastScope.hourly,
        targetTime: loaded.hourly.first.time,
        selectedLocation: locations.selectedLocation);
    debugPrint('LIVE_FORECAST_SETUP ${jsonEncode({
          'persona': settings.selectedPersonaId,
          'catalog': roasts.pack?.packVersion,
          'plannedCards': plannedCards.length,
          'builtCards': builtCardCount,
          'freshness': roastContext.freshness.name,
        })}');
    await binding.watchPerformance(() async {
      final list = find.byKey(const ValueKey('hourly-timeline-list'));
      for (var i = 0; i < 8; i++) {
        await tester.timedDrag(
            list, const Offset(0, -330), const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 250));
      }
      for (var i = 0; i < 8; i++) {
        await tester.timedDrag(
            list, const Offset(0, 330), const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pump(const Duration(seconds: 2));
    }, reportKey: 'hourly_timeline_scroll');
    await tester.tap(find.byTooltip('Close forecast'));
    await tester.pump(const Duration(milliseconds: 400));
    await open();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Close forecast'));
    await tester.pump(const Duration(milliseconds: 400));
    final after = NetworkCounters.instance.snapshot;
    expect(after, equals(before),
        reason:
            'Opening, scrolling and reopening must not add backend requests.');
    binding.reportData!['production_context'] = {
      'entryPoint': 'lib/main.dart',
      'mode': 'profile',
      'disableAnimations':
          binding.platformDispatcher.accessibilityFeatures.disableAnimations,
      'reduceMotion':
          binding.platformDispatcher.accessibilityFeatures.reduceMotion,
      'physicalWidth':
          binding.platformDispatcher.views.first.physicalSize.width,
      'physicalHeight':
          binding.platformDispatcher.views.first.physicalSize.height,
      'devicePixelRatio':
          binding.platformDispatcher.views.first.devicePixelRatio,
      'hourlyRecordsLoaded': loaded.hourly.length,
      'selectedPersona': settings.selectedPersonaId,
      'roastCatalogReady': roasts.ready,
      'roastPackVersion': roasts.pack?.packVersion,
      'roastLoadError': roasts.loadError?.toString(),
      'selectedTimelineCards': plannedCards.length,
      'initialBuiltTimelineCards': builtCardCount,
      'forecastRoastFreshness': roastContext.freshness.name,
      'isOfflineCache': loaded.isOfflineCache,
      'weatherObservedAt':
          loaded.current.displayUpdatedAt.toUtc().toIso8601String(),
      'forecastTimezone': loaded.current.timezone,
      'forecastUtcOffsetSeconds': loaded.current.timezoneOffset,
      'forecastHourMetadata': loaded.hourly
          .take(30)
          .map((hour) => {
                'targetUtc': hour.time.toUtc().toIso8601String(),
                'condition': hour.condition,
                'weatherIcon': hour.weatherIcon,
                'weatherId': hour.weatherId,
              })
          .toList(),
      'networkBefore': before,
      'networkAfter': after,
      'note':
          'Real provider data; emulator metrics are indicative, not a physical device benchmark.',
    };
    debugPrint('LIVE_FORECAST_PROFILE ${jsonEncode(binding.reportData)}');
  }, skip: !enabled);
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(ready(), isTrue,
      reason: 'Production app/live weather did not become ready.');
}
