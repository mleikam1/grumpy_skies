import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/models/hourly_timeline.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_timeline.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

HourlyForecast hour(DateTime time,
        {double temperature = 22, String condition = 'Cloudy', int? pop}) =>
    HourlyForecast(
        time: time,
        temperatureC: temperature,
        condition: condition,
        precipitationChanceKnown: pop != null,
        precipitationChance: pop ?? 0,
        weatherId: 803,
        weatherIcon: '04d');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'sorts absolute provider hours, retains current hour, deduplicates instants, leaves gaps',
      () {
    final now = DateTime.utc(2026, 10, 10, 15, 45);
    final records = [
      hour(now.add(const Duration(hours: 4))),
      hour(DateTime.utc(2026, 10, 10, 15)),
      hour(DateTime.utc(2026, 10, 10, 14)),
      hour(DateTime.utc(2026, 10, 10, 15))
    ];
    final visible = forecastTimelineHours(records, now);
    expect(visible.length, 2);
    expect(forecastIsCurrentHour(visible.first.time, now), isTrue);
    expect(visible.last.time, now.add(const Duration(hours: 4)));
  });
  test(
      'location date rollover and repeated DST hour preserve distinct instants',
      () {
    final first = DateTime.utc(2026, 11, 1, 6);
    final second = first.add(const Duration(hours: 1));
    expect(forecastHourLabel(first, 'America/Chicago', -18000), '1 AM');
    expect(forecastHourLabel(second, 'America/Chicago', -18000), '1 AM');
    expect(forecastUtcOffset(first, 'America/Chicago', -18000), 'UTC−05:00');
    expect(forecastUtcOffset(second, 'America/Chicago', -18000), 'UTC−06:00');
    expect(forecastIsCurrentHour(first, second), isFalse);
    expect(forecastIsCurrentHour(second, second), isTrue);
    expect(forecastTimelineHours([hour(first), hour(second)], first).length, 2);
    expect(
        forecastDateKey(
            DateTime.utc(2026, 10, 11, 4), 'America/Chicago', -18000),
        '2026-10-10');
    expect(
        forecastDateKey(
            DateTime.utc(2026, 10, 11, 5), 'America/Chicago', -18000),
        '2026-10-11');
    expect(
        forecastHourLabel(DateTime.utc(2026, 10, 10, 12), null, null), '12 PM');
  });

  test('fractional-offset locations retain the target local minute', () {
    final instant = DateTime.utc(2026, 10, 10, 0);
    expect(forecastHourLabel(instant, 'Asia/Kolkata', null), '5:30 AM');
    expect(forecastHourLabel(instant, 'Asia/Kathmandu', null), '5:45 AM');
  });

  testWidgets('missing provider day/night uses the selected forecast location',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11, 10); // 3 AM in San Francisco.
    final hours = [
      for (final time in [now, now.add(const Duration(hours: 9))])
        HourlyForecast(
            time: time,
            temperatureC: 16,
            condition: 'Mostly Clear',
            precipitationChance: 0,
            weatherId: 800),
    ];
    final weather = WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'current': {
        ...ApprovedFixture.weather.current.toJson(),
        'latitude': 37.7749,
        'longitude': -122.4194,
        'timezone': 'America/Los_Angeles',
        'timezoneOffset': -25200,
      },
      'hourly': hours.map((hour) => hour.toJson()).toList(),
    });
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
            body: ForecastHourlyStrip(
                hourly: hours,
                weather: weather,
                referenceTime: now,
                clock: () => now,
                timezone: 'America/Los_Angeles',
                timezoneOffset: -25200))));
    await tester.pumpAndSettle();
    List<String> assetsInside(Finder parent) => tester
        .widgetList<SvgPicture>(
            find.descendant(of: parent, matching: find.byType(SvgPicture)))
        .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName)
        .toList();
    expect(assetsInside(find.byType(ForecastHourlyStrip)), [
      'assets/fill/svg-static/clear-night.svg',
      'assets/fill/svg-static/clear-day.svg',
    ]);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(assetsInside(find.byType(ForecastHourlyTimeline)), [
      'assets/fill/svg-static/clear-night.svg',
      'assets/fill/svg-static/clear-day.svg',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'lazy full sheet, icons, scrolling, safe close: dark=$dark text=$scale',
          (tester) async {
        tester.view.physicalSize =
            scale == 2 ? const Size(320, 568) : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.utc(2026, 10, 10, 15);
        final hours = List.generate(
            29,
            (i) => hour(now.add(Duration(hours: i)),
                condition: i == 0
                    ? 'Clouds giving way to scattered showers later in the forecast hour'
                    : 'Cloudy',
                pop: i == 0 ? null : 37));
        await tester.pumpWidget(MaterialApp(
            theme: dark ? DMTheme.dark : DMTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SafeArea(
                    child: SingleChildScrollView(
                        child: ForecastHourlyStrip(
                            hourly: hours,
                            referenceTime: now,
                            clock: () => now,
                            timezone: 'America/Chicago',
                            timezoneOffset: -18000))))));
        await tester.pumpAndSettle();
        final preview = tester.widget<ListView>(find.descendant(
            of: find.byType(ForecastHourlyStrip),
            matching: find.byType(ListView)));
        // separated list builds twelve records and eleven separators.
        expect(preview.childrenDelegate.estimatedChildCount, 23);
        await tester.tap(find.text('See all'));
        await tester.pumpAndSettle();
        expect(find.byType(ForecastHourlyTimeline), findsOneWidget);
        final sheetList = find.byKey(const ValueKey('hourly-timeline-list'));
        final lazy = tester.widget<ListView>(sheetList);
        expect(lazy.childrenDelegate.estimatedChildCount, greaterThan(29));
        final icons = tester.widgetList<DaymakerWeatherIcon>(find.descendant(
            of: sheetList, matching: find.byType(DaymakerWeatherIcon)));
        expect(icons, isNotEmpty);
        for (final icon in icons) {
          expect(icon.style, WeatherIconStyle.fill);
          expect(icon.color, isNull);
          expect(icon.size, 42);
        }
        expect(find.text('0% precipitation chance'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.drag(sheetList, const Offset(0, 180));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Large text header fits the minimum sheet extent.');
        if (sheetList.evaluate().isEmpty) {
          // A drag past the minimum retains the original swipe-to-dismiss behavior.
          await tester.tap(find.text('See all'));
          await tester.pumpAndSettle();
        }
        final last = find.byKey(
            ValueKey('hourly-row-${hours.last.time.millisecondsSinceEpoch}'));
        await tester.scrollUntilVisible(last, 420,
            maxScrolls: 30,
            scrollable: find.descendant(
                of: sheetList, matching: find.byType(Scrollable)));
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close forecast'));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('expanded hourly rows have no interstitials or extra requests',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = ApprovedFixture.now;
    final hours =
        List.generate(30, (i) => hour(now.add(Duration(hours: i)), pop: 20));
    final weather = WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'hourly': hours.map((h) => h.toJson()).toList()
    });
    NetworkCounters.instance.reset();
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
            body: ForecastHourlyStrip(
                hourly: hours,
                weather: weather,
                referenceTime: now,
                clock: () => now,
                timezone: 'America/Chicago'))));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      final list = tester
          .widget<ListView>(find.byKey(const ValueKey('hourly-timeline-list')));
      final dates = hours
          .map((h) => forecastDateKey(h.time, 'America/Chicago', null))
          .toSet();
      expect(list.childrenDelegate.estimatedChildCount,
          hours.length + dates.length);
      expect(find.textContaining('take'), findsNothing);
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('hourly-roast-')),
          findsNothing);
      await tester.tap(find.byTooltip('Close forecast'));
      await tester.pumpAndSettle();
    }
    expect(NetworkCounters.instance.snapshot, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('current hazard stays prominent without a persona provider',
      (tester) async {
    final now = ApprovedFixture.now;
    final weather = WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'current': {
        ...ApprovedFixture.weather.current.toJson(),
        'weatherId': 200,
        'condition': 'Thunderstorm'
      },
      'hourly':
          List.generate(12, (i) => hour(now.add(Duration(hours: i))).toJson()),
    });
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
            body: ForecastHourlyTimeline(
                scrollController: scroll,
                hourly: weather.hourly,
                weather: weather,
                clock: () => now))));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Weather conditions need attention. Check the weather details and available official alerts.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
