import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_current_weather_card.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/monetization/ad_config.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/ad_reporting.dart';
import 'package:grumpy_skies/monetization/monetization_controller.dart';
import 'package:grumpy_skies/monetization/widgets/ad_section.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

/// This native-only fixture never runs in main.dart. It uses official test units,
/// real UMP, real AdSection ownership/visibility and an explicit weather fixture.
/// No consent bypass, production IDs, app-data clearing or creative interaction.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native UMP and one test display slot at a time', (tester) async {
    expect(kIsWeb, isFalse);
    expect(kReleaseMode, isFalse);
    final now = DateTime.now();
    final location = WeatherLocation(
        name: 'SDK verification fixture',
        country: '',
        latitude: 0,
        longitude: 0,
        updatedAt: now);
    final current = CurrentWeather(
        locationName: location.name,
        latitude: 0,
        longitude: 0,
        temperatureC: 20,
        condition: 'Clear · test fixture',
        feelsLikeC: 20,
        windKph: 8,
        humidity: 45,
        precipitationChance: 0,
        aqi: 0,
        sunrise: now,
        sunset: now.add(const Duration(hours: 8)),
        moonrise: now,
        moonset: now,
        uvIndex: 2,
        lastUpdated: now,
        sourceUpdatedAt: now,
        fetchedAt: now);
    final weather = WeatherLocationController(
        repository: const FakeWeatherRepository(), initialLocation: location);
    weather.updateWeatherSafety(
        WeatherBundle(
            current: current,
            hourly: const [],
            daily: const [],
            alertCoverageVerified: true,
            alertsCheckedAt: now),
        location);
    final reporter = _VerificationReporter();
    final controller = MonetizationController(
        weather: weather,
        reporter: reporter,
        config: const AdConfig(
            enabled: true,
            testMode: true,
            adjacentHumor: false,
            holdoutPercent: 0));
    addTearDown(controller.dispose);
    addTearDown(weather.dispose);
    controller.setRoute('/forecast');
    final status = ValueNotifier(
        'Checking privacy requirements; weather remains available.');
    addTearDown(status.dispose);

    Future<void> showFixture(AdPlacement? placement) async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: controller),
            ChangeNotifierProvider.value(value: weather),
          ],
          child: MaterialApp(
              theme: DMTheme.light,
              home: Scaffold(
                appBar: AppBar(title: const Text('DayMaker SDK verification')),
                bottomNavigationBar: const BottomAppBar(
                    child: SizedBox(
                        height: 48,
                        child: Center(
                            child: Text(
                                'Weather stays accessible · test fixture')))),
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('TEST FIXTURE · No live inventory',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ForecastCurrentWeatherCard(
                                weather: current, now: now),
                            const SizedBox(height: 12),
                            const Text(
                                'Precipitation and hourly overview: fixture only.'),
                            ValueListenableBuilder(
                                valueListenable: status,
                                builder: (_, value, __) => Text(value)),
                            if (placement != null)
                              AdSection(
                                  key: ValueKey(placement),
                                  placement: placement,
                                  contentCount: 6),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: () => status.value =
                                    'Weather action remains usable.',
                                child: const Text('Weather action')),
                            const SizedBox(height: 24),
                          ],
                        ))),
              ))));
      await tester.pump();
    }

    await showFixture(AdPlacement.forecastBanner);
    expect(find.text('68°F'), findsOneWidget);
    // Weather is rendered before consent information or ads initialization.
    final startup = controller.start();
    await _wait(
        tester, () => controller.consent.resolved, const Duration(seconds: 48));
    await startup;
    debugPrint(
        'NATIVE_AD_QA consent resolved=${controller.consent.resolved} canRequestAds=${controller.consent.canRequestAds} privacyOptionsRequired=${controller.consent.privacyOptionsRequired}');
    if (!controller.displayAllowed(AdPlacement.forecastBanner)) {
      status.value =
          'Ads blocked by real consent/SDK readiness. Weather is usable.';
      await tester.pump();
      expect(
          reporter.events.where((event) => event.kind == AdEventKind.request),
          isEmpty);
      expect(find.byType(AdWidget), findsNothing);
      debugPrint('NATIVE_AD_QA_SCREENSHOT consent_blocked');
      await _pauseForScreenshot(tester);
      await tester.ensureVisible(find.text('Weather action'));
      await tester.tap(find.text('Weather action'));
      await tester.pump();
      expect(find.text('Weather action remains usable.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      return;
    }

    for (final placement in [
      AdPlacement.forecastBanner,
      AdPlacement.memeLibraryMrec
    ]) {
      controller.setRoute(
          placement == AdPlacement.forecastBanner ? '/forecast' : '/fun/meme');
      status.value = 'Official Google test inventory: ${placement.id}';
      await showFixture(placement);
      await tester.ensureVisible(find.byType(AdSection));
      await tester.pump();
      await _wait(
          tester,
          () => reporter.events.any((event) =>
              event.placement == placement &&
              (event.kind == AdEventKind.loaded ||
                  event.kind == AdEventKind.loadFailure)),
          const Duration(seconds: 40));
      final loaded = reporter.events.any((event) =>
          event.placement == placement && event.kind == AdEventKind.loaded);
      final requests = reporter.events
          .where((event) =>
              event.placement == placement && event.kind == AdEventKind.request)
          .length;
      expect(requests, 1, reason: 'Exactly one request per section visit');
      if (loaded) {
        await _wait(tester, () => find.byType(AdWidget).evaluate().isNotEmpty,
            const Duration(seconds: 5));
        await tester.ensureVisible(find.byType(AdWidget));
        await tester.pump();
        expect(find.byType(AdWidget), findsOneWidget);
        expect(find.text('Advertisements'), findsOneWidget);
        final adSize = tester.getSize(find.byType(AdWidget));
        expect(
            adSize,
            placement == AdPlacement.forecastBanner
                ? const Size(320, 50)
                : const Size(300, 250));
        status.value = '${placement.id}: loaded official test creative.';
      } else {
        status.value =
            '${placement.id}: no fill or SDK load failure. Weather stays available.';
        expect(find.byType(AdWidget), findsNothing);
        expect(find.text('Advertisements'), findsNothing);
      }
      await tester.pump();
      debugPrint(
          'NATIVE_AD_QA_SCREENSHOT ${placement.id}_${loaded ? 'loaded' : 'unavailable'}');
      await _pauseForScreenshot(tester);
      expect(
          reporter.events
              .where((event) =>
                  event.placement == placement &&
                  event.kind == AdEventKind.request)
              .length,
          requests);
      // Route retirement removes platform views rather than hiding creatives.
      controller.setRoute('/settings');
      await showFixture(null);
      expect(find.byType(AdWidget), findsNothing);
    }
    debugPrint(
        'NATIVE_AD_QA completed requests=${reporter.events.where((event) => event.kind == AdEventKind.request).length} impressions=${reporter.events.where((event) => event.kind == AdEventKind.impression).length}');
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _wait(
    WidgetTester tester, bool Function() ready, Duration timeout) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

Future<void> _pauseForScreenshot(WidgetTester tester) async {
  for (var i = 0; i < 32; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

class _VerificationReporter implements AdReporter {
  final events = <AdEvent>[];
  @override
  void report(AdEvent event) {
    events.add(event);
    debugPrint(
        'NATIVE_AD_QA ${event.placement.id} ${event.kind.name} ${event.reason ?? ''}');
  }
}
