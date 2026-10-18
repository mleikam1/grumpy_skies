import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/guidance/domain/guidance.dart';
import 'package:grumpy_skies/features/guidance/forecast_guidance.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/widgets/guidance_view.dart';
import 'package:grumpy_skies/models/guidance_preferences.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'guidance_test_support.dart';

void main() {
  testWidgets(
      'fresh layout visibility excludes same-frame hidden replacement and repeated paints',
      (tester) async {
    final controller = GuidanceController(
        catalog: testGuidanceCatalog(), clock: () => ApprovedFixture.now);
    final settings = SettingsController();
    var hidden = false;
    var bundle = guidanceTestBundle();
    late StateSetter update;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
            theme: DMTheme.lightTheme,
            home: Scaffold(body: StatefulBuilder(builder: (context, setter) {
              update = setter;
              return Offstage(
                  offstage: hidden,
                  child: ForecastGuidanceView(
                      weather: bundle, surface: GuidanceSurface.todaySummary));
            })))));
    await tester.pump();
    expect(controller.history.entries, hasLength(1));
    for (var i = 0; i < 1000; i++) {
      await tester.pump();
    }
    expect(controller.history.entries, hasLength(1));
    update(() {
      hidden = true;
      bundle = guidanceTestBundle(heat: true);
    });
    await tester.pump();
    await tester.pump();
    expect(controller.history.entries, hasLength(1));
    final hiddenEvaluations = controller.evaluationCount;
    await tester.pump(const Duration(minutes: 1));
    expect(controller.evaluationCount, hiddenEvaluations);
    update(() {
      hidden = false;
    });
    await tester.pump();
    await tester.pump();
    expect(controller.history.entries, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    settings.dispose();
  });

  testWidgets('visible empty slot reevaluates locally at a clock boundary',
      (tester) async {
    var now = ApprovedFixture.now;
    final source = guidanceTestBundle();
    final bundle = WeatherBundle(
        current: source.current,
        location: source.location,
        forecastSource: source.forecastSource,
        daily: [],
        hourly: [
          HourlyForecast(
              time: now,
              temperatureC: 20,
              condition: 'Clear',
              weatherId: 800,
              weatherIcon: '01d',
              precipitationChance: 0),
          HourlyForecast(
              time: now.add(const Duration(hours: 4)),
              temperatureC: 20,
              condition: 'Rain',
              weatherId: 501,
              weatherIcon: '10d',
              precipitationChance: 70),
        ]);
    final location = forecastGuidanceLocation(bundle);
    final adapted =
        GuidanceWeatherAdapter.fromBundle(bundle, location: location);
    final evidence =
        WeatherEvidence(location: location, hourly: adapted.hourly);
    final displayed = GuidanceInterval(now, now.add(const Duration(hours: 1)));
    final controller =
        GuidanceController(catalog: testGuidanceCatalog(), clock: () => now);
    final settings = SettingsController();
    // The future window is 14:00–15:00 in the viewed Chicago location.
    settings.setGuidancePreferences(const GuidancePreferences(
        driving: true, commuteStartMinute: 840, commuteEndMinute: 900));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
            theme: DMTheme.lightTheme,
            home: Scaffold(
                body: Column(children: [
              const Text('Existing forecast detail'),
              GuidanceView(
                  weather: evidence,
                  context: GuidanceContext(
                      surface: GuidanceSurface.todaySummary,
                      location: location,
                      window: displayed)),
            ])))));
    await tester.pump();
    expect(find.byTooltip('Why this tip?'), findsNothing);
    final before = controller.evaluationCount;
    now = now.add(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));
    await tester.pump();
    expect(controller.evaluationCount, greaterThan(before));
    expect(find.byTooltip('Why this tip?'), findsOneWidget);
    expect(controller.history.entries, hasLength(1));
    expect(controller.localHistoryWrites, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    settings.dispose();
  });
}
