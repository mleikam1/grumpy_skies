import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_details_sheet.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/plancast_guidance_adapter.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/models/guidance_preferences.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plancast_guidance_test.dart';

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'production navigation and 1000 mounted-screen selections add no service calls',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = guidanceCatalog();
    final measurements = <String, Object>{};

    Map<String, int> namedCounts(List<int> counts) => Map.fromIterables([
          'planCastForecastRepositoryLoads',
          'forwardGeocodingCalls',
          'reverseGeocodingCalls',
          'calendarListReads',
          'calendarEventReads',
          'protectedStorageReads',
          'protectedStorageWrites',
          'notificationQueueWrites',
          'calendarPermissionRequests',
          'calendarPermissionChecks',
          'calendarChangeSubscriptions',
          'deviceAreaRefreshes',
        ], counts);

    Future<List<int>> exercise(bool enabled) async {
      final now = ApprovedFixture.now;
      final session = ApprovedPreviewSession();
      await session.initialize();
      session.settings
          .setGuidancePreferences(GuidancePreferences(enabled: enabled));
      final platform = CountingGuidancePlatform()
        ..records = [
          {
            'id': 'explicit-outdoor',
            'calendarId': 'work',
            'title': 'Synthetic outdoor plan',
            'startMs': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
            'endMs': now.add(const Duration(hours: 5)).millisecondsSinceEpoch,
            'timeZone': 'America/Chicago',
            'latitude': guidanceVenue.lat,
            'longitude': guidanceVenue.lon,
          }
        ];
      final weather = CountingGuidanceWeather(clock: () => now);
      final area = CountingGuidanceArea(now: now);
      final plans = PlanCastController(
          weatherRepository: weather,
          platform: platform,
          deviceAreaService: area,
          clock: () => now);
      await plans.connect();
      await plans.selectCalendars({'work'});
      await plans.setEventOverride(plans.events.single.event,
          environment: EventEnvironment.outdoor);
      var localWrites = 0;
      final guidance = GuidanceController(
          catalog: catalog,
          clock: () => now,
          persistHistory: (_) async {
            localWrites++;
          });
      final app = MultiProvider(providers: [
        ChangeNotifierProvider<PlanCastController>.value(value: plans),
        ChangeNotifierProvider<GuidanceController>.value(value: guidance),
      ], child: session.build(reducedMotion: true));
      await tester.pumpWidget(app);
      await _frames(tester);
      final afterInitialLoad = serviceCounts(platform, weather, area);
      final initialWeatherRequests = session.weather.requestCount;
      expect(find.byType(ForecastDailyStrip), findsOneWidget);

      // Use the real existing daily sheet and route stack from the live widget
      // context. Its guidance consumes the exact displayed WeatherBundle.
      final dailyContext = tester.element(find.byType(ForecastDailyStrip));
      showDailyForecastSheet(dailyContext,
          daily: ApprovedFixture.weather.daily,
          weather: ApprovedFixture.weather,
          clock: () => now,
          referenceTime: now,
          timezone: ApprovedFixture.weather.current.timezone);
      await _frames(tester);
      expect(
          find.byKey(const ValueKey('daily-forecast-details')), findsOneWidget);
      Navigator.of(tester
              .element(find.byKey(const ValueKey('daily-forecast-details'))))
          .pop();
      await _frames(tester);

      session.router.go(AppRoutes.planCast);
      await _frames(tester);
      expect(find.byType(PlanCastScreen), findsOneWidget);
      final item = plans.currentEvents.single;
      openPlanCastEvent(tester.element(find.byType(PlanCastScreen)), item);
      await _frames(tester);
      expect(find.text('Event details'), findsOneWidget);
      if (enabled) {
        final explanation = find.byTooltip('Why this tip?').hitTestable();
        // Summary and details may dedupe the same action. A local reset lets
        // this explicit detail visibility exercise its own Why/dismiss path.
        if (explanation.evaluate().isEmpty) {
          await guidance.resetHistory();
          await _frames(tester);
        }
        final tip = find.byTooltip('Why this tip?').hitTestable();
        expect(tip, findsWidgets);
        await tester.tap(tip.first);
        await _frames(tester);
        expect(find.text('Why this tip?'), findsOneWidget);
        final dismiss = find.text('Hide this tip for this situation');
        await tester.scrollUntilVisible(dismiss, 500,
            scrollable: find.byType(Scrollable).last, maxScrolls: 25);
        await tester.tap(dismiss);
        await _frames(tester);
      }
      Navigator.of(tester.element(find.text('Event details'))).pop();
      await _frames(tester);

      final input = PlanCastGuidanceAdapter.fromEventSnapshot(
          item: item,
          bundle: plans.cachedGuidanceWeatherForEvent(item),
          now: now)!;
      for (var i = 0; i < 1000; i++) {
        guidance.select(
            weather: input.weather,
            context: input.context,
            preferences: GuidancePreferences(enabled: enabled),
            scopeKey: 'visible-plan-cost-check');
        if (i % 100 == 0) {
          // Real settings saves, provider notifications and widget frames are
          // local. Their weather snapshot and calendar inputs do not change.
          session.settings.setGuidancePreferences(GuidancePreferences(
              enabled: enabled,
              walking: i.isEven,
              outingMinutes: i % 200 == 0 ? 30 : 45));
          await _frames(tester);
        }
      }
      expect(serviceCounts(platform, weather, area), afterInitialLoad);
      expect(session.weather.requestCount, initialWeatherRequests);
      expect(session.network.blockedRequests, 0);
      expect(
          guidance.evaluationCount, enabled ? greaterThanOrEqualTo(1000) : 0);
      expect(guidance.history.entries.length, lessThanOrEqualTo(100));
      await guidance.flush();
      expect(localWrites, lessThan(20));
      expect(tester.takeException(), isNull);
      final result = [
        ...serviceCounts(platform, weather, area),
        session.weather.requestCount,
        session.network.blockedRequests
      ];
      final after = serviceCounts(platform, weather, area);
      measurements[enabled ? 'tipsEnabled' : 'tipsDisabled'] = {
        'beforeGuidanceInteractions': namedCounts(afterInitialLoad),
        'afterGuidanceInteractions': namedCounts(after),
        'interactionDeltas': namedCounts([
          for (var i = 0; i < after.length; i++) after[i] - afterInitialLoad[i],
        ]),
        'todayForecastRepositoryLoads': session.weather.requestCount,
        'blockedRemoteHttpAttempts': session.network.blockedRequests,
        'guidanceEvaluations': guidance.evaluationCount,
        'explicitSelectionAttempts': 1000,
        'localHistoryWrites': guidance.localHistoryWrites,
        'retainedVisibleImpressions': guidance.history.entries.length,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      guidance.dispose();
      plans.dispose();
      session.dispose();
      return result;
    }

    final withoutTips = await exercise(false);
    final withTips = await exercise(true);
    expect(withTips, withoutTips,
        reason:
            'Guidance changes local rendering/history only. Existing weather, '
            'calendar, location, notification and protected-storage calls are identical.');
    final reportPath = Platform.environment['GUIDANCE_COST_REPORT'];
    if (reportPath != null && reportPath.isNotEmpty) {
      final report = File(reportPath);
      report.parent.createSync(recursive: true);
      report.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'test': 'production navigation and 1000 mounted-screen selections',
        'snapshotTimeUtc': ApprovedFixture.now.toIso8601String(),
        'mode':
            'Synthetic local adapters; no live calendars or remote service calls',
        'surfaces': [
          'Today',
          'daily details',
          'PlanCast',
          'event details',
          'Why this tip'
        ],
        'offOnServiceCountsEqual': true,
        'measurements': measurements,
      }));
    }
  });

  test(
      'guidance has no remote clients, new subscriptions or request-capable repositories',
      () {
    final files = Directory('lib/features/guidance')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
          source,
          isNot(matches(RegExp(
              r'''import\s+['"].*(?:package:http|dio/|firebase|weather_repository|calendar_repository|location_service|plancast_platform)'''))),
          reason: '${file.path} must only consume local values.');
      expect(source, isNot(contains('Timer.periodic(')));
    }
  });
}
