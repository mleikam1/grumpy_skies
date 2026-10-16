import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';
import 'package:grumpy_skies/core/weather/openweather_icon_mapper.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_details_sheet.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_timeline.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';

final now = DateTime.utc(2026, 10, 15, 12, 30);
final days = List.generate(
    10,
    (i) => DailyForecast(
        date: DateTime(2026, 10, 15 + i),
        minTempC: 0,
        maxTempC: 12,
        condition: i.isEven ? 'Snow' : 'Cloudy',
        temperatureKnown: i != 0,
        precipitationChanceKnown: i != 0,
        precipitationChance: 0,
        weatherId: i.isEven ? 600 : 803));
final hours = List.generate(
    30,
    (i) => HourlyForecast(
        time: DateTime.utc(2026, 10, 15, 12 + i),
        temperatureC: 0,
        condition: i.isEven ? 'Rain' : 'Clear',
        temperatureKnown: i != 0,
        precipitationChanceKnown: i != 0,
        precipitationChance: 0,
        weatherId: i.isEven ? 500 : 800,
        weatherIcon: i.isEven ? '10d' : '01n'));

Widget subject({bool dark = false, double scale = 1}) => MaterialApp(
    theme: dark ? DMTheme.dark : DMTheme.light,
    home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      ForecastDailyStrip(
                          daily: days, referenceTime: now, timezone: 'UTC'),
                      ForecastHourlyList(
                          hourly: hours,
                          referenceTime: now,
                          timezone: 'UTC',
                          clock: () => now),
                    ]))))));

void main() {
  testWidgets(
      'swapped previews animate real assets and recover after theme, scroll, motion and sheets',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DaymakerWeatherIcon.debugAnimateInTests = true;
    addTearDown(() => DaymakerWeatherIcon.debugAnimateInTests = false);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(autoPlayAnimatedImages: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final slugs = <String>{
      for (final day in days)
        OpenWeatherIconMapper.map(conditionId: day.weatherId),
      for (final hour in hours)
        OpenWeatherIconMapper.map(
            conditionId: hour.weatherId, openWeatherIconCode: hour.weatherIcon),
    };
    await tester.runAsync(() => Future.wait(slugs.map((slug) => AssetLottie(
            'assets/fill/lottie/$slug.json',
            package: WeatherIcons.packageName,
            bundle: rootBundle)
        .load())));
    Future<void> frames() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Finder motionIn(Type type) => find.descendant(
        of: find.byType(type), matching: find.byType(RawLottie));
    await tester.pumpWidget(subject());
    await frames();
    expect(motionIn(ForecastDailyStrip), findsWidgets);
    expect(motionIn(ForecastHourlyList), findsWidgets);
    final dailyProgress =
        tester.widget<RawLottie>(motionIn(ForecastDailyStrip).first).progress;
    final hourlyProgress =
        tester.widget<RawLottie>(motionIn(ForecastHourlyList).first).progress;
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.widget<RawLottie>(motionIn(ForecastDailyStrip).first).progress,
        isNot(dailyProgress));
    expect(
        tester.widget<RawLottie>(motionIn(ForecastHourlyList).first).progress,
        isNot(hourlyProgress));
    await tester.pumpWidget(subject(dark: true));
    await frames();
    expect(motionIn(ForecastDailyStrip), findsWidgets);
    expect(motionIn(ForecastHourlyList), findsWidgets);
    // A small viewport makes the retained daily strip genuinely scroll offscreen.
    tester.view.physicalSize = const Size(390, 400);
    await tester.pump();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -350));
    await frames();
    expect(motionIn(ForecastDailyStrip), findsNothing);
    expect(motionIn(ForecastHourlyList), findsWidgets);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
            autoPlayAnimatedImages: true, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(find.byType(RawLottie), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(autoPlayAnimatedImages: true);
    await tester.ensureVisible(find.byType(ForecastDailyStrip));
    await frames();
    expect(motionIn(ForecastDailyStrip), findsWidgets);
    final action = find.descendant(
        of: find.byType(ForecastHourlyList), matching: find.text('See all'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await frames();
    expect(motionIn(ForecastHourlyTimeline), findsWidgets);
    await tester.tap(find.byTooltip('Close forecast'));
    await frames();
    expect(motionIn(ForecastHourlyList), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
  testWidgets(
      'daily strip and hourly rows retain condition-specific icons and unknowns',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    final strip = tester.widget<ListView>(
        find.byKey(const PageStorageKey('daily-forecast-strip')));
    expect(strip.scrollDirection, Axis.horizontal);
    expect(strip.childrenDelegate.estimatedChildCount, 13); // 7 tiles + 6 gaps.
    expect(find.byType(ForecastHourlyRow), findsNWidgets(12));
    expect(find.text('High —'), findsOneWidget);
    expect(find.text('Low —'), findsOneWidget);
    expect(find.text('Precip. —'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(11));
    expect(find.text('Now'), findsOneWidget);
    final dailyIcons = tester.widgetList<DaymakerWeatherIcon>(find.descendant(
        of: find.byType(ForecastDailyStrip),
        matching: find.byType(DaymakerWeatherIcon)));
    expect(dailyIcons.map((icon) => icon.conditionId).toSet(), {600, 803});
    final hourlyIcons = tester.widgetList<DaymakerWeatherIcon>(find.descendant(
        of: find.byType(ForecastHourlyList),
        matching: find.byType(DaymakerWeatherIcon)));
    expect(hourlyIcons.map((icon) => icon.openWeatherIconCode).toSet(),
        {'10d', '01n'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'See all preserves full existing hourly timeline and all future daily data',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ForecastDailyStrip), matching: find.text('See all')));
    await tester.pumpAndSettle();
    expect(find.byType(ForecastHourlyTimeline), findsNothing);
    final dailyList = find.byKey(const ValueKey('daily-forecast-details'));
    expect(
        tester.widget<ListView>(dailyList).childrenDelegate.estimatedChildCount,
        19);
    final lastDay =
        find.byKey(const ValueKey('detail-daily-2026-10-24T00:00:00.000Z'));
    await tester.scrollUntilVisible(lastDay, 350,
        scrollable:
            find.descendant(of: dailyList, matching: find.byType(Scrollable)));
    // A row's center may be blank space between its text columns. Verify its
    // actual date and final precipitation field are reachable and visible.
    final lastDayText =
        find.descendant(of: lastDay, matching: find.byType(Text));
    await tester.ensureVisible(lastDayText.first);
    await tester.pumpAndSettle();
    expect(lastDayText.first.hitTestable(), findsOneWidget);
    await tester.ensureVisible(lastDayText.last);
    await tester.pumpAndSettle();
    expect(lastDayText.last.hitTestable(), findsOneWidget);
    expect(find.byType(ForecastDailyDetailRow), findsWidgets);
    await tester.tap(find.byTooltip('Close forecast'));
    await tester.pumpAndSettle();
    final action = find.descendant(
        of: find.byType(ForecastHourlyList), matching: find.text('See all'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(ForecastHourlyTimeline), findsOneWidget);
    final timeline = find.byKey(const ValueKey('hourly-timeline-list'));
    final lastHour = find.byKey(
        ValueKey('hourly-row-${hours.last.time.millisecondsSinceEpoch}'));
    await tester.scrollUntilVisible(lastHour, 500,
        scrollable:
            find.descendant(of: timeline, matching: find.byType(Scrollable)));
    expect(lastHour.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 820.0]) {
      testWidgets(
          'current ${dark ? 'dark' : 'light'} presentation fits width $width at 200% text',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(subject(dark: dark, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(ForecastHourlyRow).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
