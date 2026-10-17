import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_settings_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_location_controls.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';

final _now = DateTime(2026, 10, 17, 9);
const _area = LocationCandidate(
    name: 'Overland Park',
    country: 'US',
    lat: 38.98,
    lon: -94.67,
    source: 'device');
const _home = LocationCandidate(
    name: 'Home', country: '', lat: 38.95, lon: -94.65, source: 'saved');

PlanCastEventWeather _item(
        {bool recurring = false, bool invite = false, bool manual = false}) =>
    PlanCastEventWeather(
      event: CalendarEvent(
          id: 'event',
          nativeId: 'native',
          calendarId: 'one',
          title: 'An unchanged calendar appointment',
          startUtc: _now.toUtc(),
          endUtc: _now.toUtc().add(const Duration(hours: 1)),
          timeZone: 'America/Chicago',
          isRecurring: recurring,
          recurringId: recurring ? 'series' : null,
          locationText: invite ? 'Miami Beach' : '',
          latitude: invite ? 25.79 : null,
          longitude: invite ? -80.13 : null),
      venue: _area,
      resolvedLocation: ResolvedLocation(
          candidate: _area,
          source:
              manual ? LocationSource.userOverride : LocationSource.currentArea,
          precision: LocationPrecision.area,
          evidenceQuality: LocationEvidenceQuality.assumed,
          reason: 'Using your area',
          resolvedAt: _now),
      assessment: const EventWeatherAssessment(
          coverage: ForecastCoverage.hourly,
          impact: WeatherImpact.low,
          explanation: 'Clear during your plan.',
          minTemperatureC: 20,
          maxTemperatureC: 20),
    );

class _Controller extends PlanCastController {
  _Controller(this.item)
      : super(
            weatherRepository: const FakeWeatherRepository(),
            platform: PlanCastPlatform(supported: false),
            clock: () => _now) {
    calendarPermission = 'authorized';
    selectedCalendarIds = {'one', 'two', 'three', 'four'};
    calendars = const [
      DeviceCalendar(
          id: 'one',
          name: 'Personal',
          colorArgb: 0xff389e96,
          accountName: 'Local calendar account'),
      DeviceCalendar(
          id: 'two',
          name:
              'A very long family calendar name that must remain readable without clipping',
          colorArgb: 0xffe9b355),
      DeviceCalendar(id: 'three', name: 'Work'),
      DeviceCalendar(id: 'four', name: 'Birthdays'),
      DeviceCalendar(id: 'five', name: 'Sports'),
    ];
    smartLocations = SmartLocationState(savedPlaces: [
      SavedPlanCastPlace(
          id: 'home', label: 'Home', candidate: _home, createdAt: _now),
    ]);
  }
  final PlanCastEventWeather item;
  int calendarSaves = 0, locationSaves = 0, resets = 0, areaRequests = 0;
  LocationChoice? savedChoice;
  LocationRuleScope? savedScope;
  @override
  bool get supported => true;
  @override
  bool get connected => true;
  @override
  LocationCandidate? get currentArea => _area;
  @override
  List<PlanCastEventWeather> get currentEvents => [item];
  @override
  Future<void> selectCalendars(Set<String> ids) async {
    calendarSaves++;
    selectedCalendarIds = {...ids};
    notifyListeners();
  }

  @override
  Future<void> useCurrentArea({bool requestPermission = true}) async {
    areaRequests++;
  }

  @override
  Future<void> setLocationChoice(CalendarEvent event, LocationChoice choice,
      {LocationRuleScope scope = LocationRuleScope.occurrence}) async {
    locationSaves++;
    savedChoice = choice;
    savedScope = scope;
  }

  @override
  Future<void> resetEventLocation(CalendarEvent event) async {
    resets++;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _Controller c,
      {double width = 390, double scale = 1, bool dark = false}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      c.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider<PlanCastController>.value(
        value: c,
        child: MaterialApp(
          theme: dark ? DMTheme.dark : DMTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => Column(children: [
                        TextButton(
                            onPressed: () =>
                                changePlanCastLocation(context, c.item),
                            child: const Text('Location')),
                        TextButton(
                            onPressed: () =>
                                selectPlanCastCalendars(context, c),
                            child: const Text('Calendars')),
                      ]))),
        )));
    await tester.pumpAndSettle();
  }

  testWidgets('location preselects actual area and cancel performs no work',
      (tester) async {
    final c = _Controller(_item());
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    final current =
        find.byKey(const ValueKey('plancast-location-choice-current'));
    expect(
        find.descendant(
            of: current, matching: find.byIcon(Icons.radio_button_checked)),
        findsOneWidget);
    expect(find.text('Location from invite'), findsNothing);
    expect(find.text('Exact venue coordinates'), findsNothing);
    expect(find.text('Missing-location events in this series'), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('plancast-location-choice-saved:home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(c.locationSaves, 0);
    expect(c.areaRequests, 0);
    expect(c.resets, 0);
  });

  testWidgets(
      'unchanged Save does no work; explicit Current area refreshes a nonfresh sample',
      (tester) async {
    final c = _Controller(_item());
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.locationSaves, 0);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current area'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.locationSaves, 1);
    expect(c.areaRequests, 1);
    expect(c.savedScope, LocationRuleScope.occurrence);
  });

  testWidgets('valid invite choice is available and scopes are secondary',
      (tester) async {
    final c = _Controller(_item(invite: true));
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    expect(find.text('Location from invite'), findsOneWidget);
    await tester.tap(find.text('Location from invite'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply to…'));
    await tester.tap(find.text('Apply to…'));
    await tester.pumpAndSettle();
    expect(find.text('Missing-location events in this series'), findsNothing);
    await tester.tap(find.text('This event').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.savedChoice?.candidate?.lat, 25.79);
    expect(c.savedScope, LocationRuleScope.occurrence);
    expect(c.item.event.startUtc, _now.toUtc());
  });

  testWidgets(
      'series scope previews affected plans and saved place commits once',
      (tester) async {
    final c = _Controller(_item(recurring: true));
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('plancast-location-choice-saved:home')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply to…'));
    await tester.tap(find.text('Apply to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing-location events in this series'));
    await tester.pumpAndSettle();
    expect(find.textContaining('currently loaded'), findsOneWidget);
    expect(c.locationSaves, 0);
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.savedChoice?.savedPlaceId, 'home');
    expect(c.savedScope, LocationRuleScope.seriesMissing);
    expect(c.locationSaves, 1);
  });

  testWidgets('automatic reset remains staged until Save', (tester) async {
    final c = _Controller(_item(manual: true));
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use automatic location'));
    await tester.tap(find.text('Use automatic location'));
    await tester.pumpAndSettle();
    expect(c.resets, 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(c.resets, 0);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use automatic location'));
    await tester.tap(find.text('Use automatic location'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.resets, 1);
    expect(c.locationSaves, 0);
  });

  testWidgets(
      'manual recurring choice preselects the saved place without a write',
      (tester) async {
    final c = _Controller(_item(recurring: true, manual: true));
    c.smartLocations = c.smartLocations.copyWith(rules: [
      ScopedLocationRule(
          id: 'legacy-series',
          scope: LocationRuleScope.legacy,
          targetId: c.item.event.recurringKey,
          choice: const LocationChoice.savedPlace('home'),
          createdAt: _now),
    ]);
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    final saved =
        find.byKey(const ValueKey('plancast-location-choice-saved:home'));
    expect(
        find.descendant(
            of: saved, matching: find.byIcon(Icons.radio_button_checked)),
        findsOneWidget);
    expect(find.text('Use automatic location'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(c.resets, 0);
    expect(c.locationSaves, 0);
  });

  testWidgets(
      'location Save stays reachable at 2x and city keyboard scrolls safely',
      (tester) async {
    final c = _Controller(_item());
    await pump(tester, c, width: 360, scale: 2);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plancast-save-location')).hitTestable(),
        findsOneWidget);
    await tester.ensureVisible(find.text('Search for a city'));
    await tester.tap(find.text('Search for a city'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final query = find.byKey(const ValueKey('plancast-city-query'));
    await tester.ensureVisible(query);
    await tester.tap(query);
    await tester.enterText(query, 'Chicago');
    await tester.pumpAndSettle();
    expect(query.hitTestable(), findsOneWidget);
    expect(c.locationSaves, 0);
    expect(c.areaRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unresolved area keeps Save disabled until a location is selected',
      (tester) async {
    final c = _Controller(PlanCastEventWeather(
        event: _item().event,
        assessment: const EventWeatherAssessment(
            coverage: ForecastCoverage.needsLocation,
            impact: WeatherImpact.unavailable,
            explanation: 'Choose a weather area.')));
    await pump(tester, c);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('plancast-save-location'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(find.text('Apply to…'));
    await tester.tap(find.text('Apply to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing-location events in this calendar'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(
        find.byKey(const ValueKey('plancast-location-choice-online')));
    await tester
        .tap(find.byKey(const ValueKey('plancast-location-choice-online')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(c.locationSaves, 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(c.locationSaves, 0);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'calendar sheet preserves four selections at $width dark=$dark large text',
          (tester) async {
        final c = _Controller(_item());
        await pump(tester, c, width: width, scale: 1.8, dark: dark);
        await tester.tap(find.text('Calendars'));
        await tester.pumpAndSettle();
        expect(find.text('Manage calendars'), findsOneWidget);
        expect(find.text('Local calendar account'), findsOneWidget);
        expect(
            tester
                .widget<CheckboxListTile>(
                    find.byKey(const ValueKey('plancast-calendar-one')))
                .value,
            isTrue);
        expect(
            find.byKey(const ValueKey('plancast-save-calendars')).hitTestable(),
            findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('plancast-calendar-one')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(c.selectedCalendarIds, {'one', 'two', 'three', 'four'});
        expect(c.calendarSaves, 0);
        await tester.tap(find.text('Calendars'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('plancast-save-calendars')));
        await tester.pumpAndSettle();
        expect(c.calendarSaves, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('calendar Done commits exact new selection once', (tester) async {
    final c = _Controller(_item());
    await pump(tester, c);
    await tester.tap(find.text('Calendars'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plancast-calendar-one')));
    await tester
        .ensureVisible(find.byKey(const ValueKey('plancast-calendar-five')));
    await tester.tap(find.byKey(const ValueKey('plancast-calendar-five')));
    await tester.pumpAndSettle();
    expect(c.calendarSaves, 0);
    await tester.tap(find.byKey(const ValueKey('plancast-save-calendars')));
    await tester.pumpAndSettle();
    expect(c.selectedCalendarIds, {'two', 'three', 'four', 'five'});
    expect(c.calendarSaves, 1);
    expect(tester.takeException(), isNull);
  });
}
