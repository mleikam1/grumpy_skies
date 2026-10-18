import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/app/daymaker_app.dart';
import 'package:grumpy_skies/app/daymaker_router.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_current_weather_card.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_card.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import '../integration_test/plancast_smart_locations_preview.dart'
    show PlanCastPreviewArea;
import 'helpers/daymaker_test_helpers.dart';
import 'plancast/plancast_core_test.dart' as fixtures;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('connected PlanCast moves from Today into the second primary tab',
      (tester) async {
    tester.setDayMakerSurfaceSize(const Size(390, 844));
    final controller = PlanCastController(
        platform: fixtures.FakePlatform(),
        weatherRepository: fixtures.FakeWeather(),
        // Native geolocation is outside this navigation regression. Use the
        // same deterministic device-area boundary as our PlanCast UI fixtures.
        deviceAreaService: PlanCastPreviewArea(fixtures.now, denied: true),
        clock: () => fixtures.now);
    await controller.connect();
    await controller.selectCalendars({'work'});
    expect(controller.connected, isTrue);
    final router = createDaymakerRouter(initialLocation: AppRoutes.forecast);
    await tester.pumpWidget(ChangeNotifierProvider<PlanCastController>.value(
        value: controller,
        child: await buildDayMakerTestProviders(
            child: DaymakerApp(routerConfig: router))));
    await tester.pumpAndSettle();

    void expectTodayWeather() {
      expect(find.byType(ForecastScreen), findsOneWidget);
      expect(find.byType(ForecastCurrentWeatherCard), findsOneWidget);
      expect(find.byType(ForecastDailyStrip), findsOneWidget);
      expect(find.byType(ForecastHourlyList), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ForecastDailyStrip)).dy,
          lessThan(tester.getTopLeft(find.byType(ForecastHourlyList)).dy));
      expect(find.byType(PlanCastCard), findsNothing);
      expect(find.text('View my PlanCast'), findsNothing);
    }

    expectTodayWeather();
    expect(find.bySemanticsLabel('PlanCast tab'), findsOneWidget,
        reason:
            'Today exposes one PlanCast destination without a duplicate card.');
    await tester.tap(find.bySemanticsLabel('PlanCast tab'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.planCast);
    expect(find.byType(PlanCastScreen), findsOneWidget);
    expect(find.byType(DmBottomNav), findsOneWidget);
    expect(
        tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex, 1);
    expect(controller.selectedCalendarIds, {'work'});
    await tester.tap(find.bySemanticsLabel('Today tab'));
    await tester.pumpAndSettle();
    expectTodayWeather();
    expect(
        tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    controller.dispose();
  });

  for (final direct in [true, false]) {
    testWidgets(
        'PlanCast ${direct ? 'direct' : 'pushed'} event/day link retains the shell',
        (tester) async {
      tester.setDayMakerSurfaceSize(const Size(390, 844));
      final target = Uri(path: AppRoutes.planCast, queryParameters: {
        'event': 'saved/event with spaces',
        'day': '2026-10-19',
      }).toString();
      final router = createDaymakerRouter(
          initialLocation: direct ? target : AppRoutes.forecast);
      await tester.pumpWidget(await buildDayMakerTestProviders(
          child: DaymakerApp(routerConfig: router)));
      await tester.pumpAndSettle();
      if (!direct) {
        router.push(target);
        await tester.pumpAndSettle();
      }
      final screen = tester.widget<PlanCastScreen>(find.byType(PlanCastScreen));
      expect(screen.eventId, 'saved/event with spaces');
      expect(screen.day, DateTime(2026, 10, 19));
      expect(GoRouterState.of(tester.element(find.byType(PlanCastScreen))).uri,
          Uri.parse(target));
      if (direct) {
        expect(router.routeInformationProvider.value.uri, Uri.parse(target));
      } else {
        // Imperative pushes preserve the existing browser URL by default in
        // go_router; the active route and back stack still retain the link.
        expect(router.canPop(), isTrue);
      }
      expect(find.byType(DmBottomNav), findsOneWidget);
      expect(
          tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex, 1);
      expect(tester.takeException(), isNull);
      if (!direct) {
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(ForecastScreen), findsOneWidget);
        expect(
            router.routeInformationProvider.value.uri.path, AppRoutes.forecast);
        expect(
            tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex,
            0);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('four-tab navigation fits $width at 2x accessibility text',
        (tester) async {
      await tester.pumpDayMakerRoute(
          initialLocation: AppRoutes.planCast,
          viewport: DayMakerTestViewport(
              label: '$width phone', size: Size(width, 844)),
          textScale: 2);
      final nav = find.byType(DmBottomNav);
      expect(tester.widget<DmBottomNav>(nav).currentIndex, 1);
      final screen = Rect.fromLTWH(0, 0, width, 844);
      final rects = <Rect>[];
      for (final item in DmBottomNav.defaultItems) {
        final tab = find.bySemanticsLabel(item.semanticLabel);
        expect(tab.hitTestable(), findsOneWidget);
        final rect = tester.getRect(tab);
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
        expect(rect.height, greaterThanOrEqualTo(48));
        rects.add(rect);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
