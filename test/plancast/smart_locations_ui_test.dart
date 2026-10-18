import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/smart_location_travel.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_card.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_presentation.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_location_controls.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';

final _now = DateTime(2026, 10, 16, 9);
const _area = LocationCandidate(
    name: 'Overland Park',
    country: 'US',
    lat: 38.98,
    lon: -94.67,
    source: 'device');
const _city = LocationCandidate(
    name: 'Miami Beach',
    country: 'US',
    lat: 25.79,
    lon: -80.13,
    source: 'city');
const _weather = EventWeatherAssessment(
    coverage: ForecastCoverage.hourly,
    impact: WeatherImpact.low,
    explanation: 'Clear during your plan.',
    condition: 'Clear',
    weatherIcon: '01d',
    minTemperatureC: 22,
    maxTemperatureC: 24,
    peakPrecipitationChance: 10,
    maxWindKph: 12,
    advice: 'Bring a light layer.');

PlanCastEventWeather _item(String id,
    {int day = 16,
    String calendar = 'personal',
    String locationText = '',
    bool online = false,
    ForecastCoverage? coverage,
    bool missing = false,
    bool unknownCondition = false}) {
  final start = DateTime(2026, 10, day, 11).toUtc();
  return PlanCastEventWeather(
    event: CalendarEvent(
        id: id,
        nativeId: id,
        calendarId: calendar,
        title: id,
        locationText: locationText,
        startUtc: start,
        endUtc: start.add(const Duration(hours: 1)),
        timeZone: 'UTC',
        recurringId: 'series-$id',
        isRecurring: true),
    venue: missing || online ? null : _area,
    participation:
        online ? EventParticipation.online : EventParticipation.unknown,
    resolvedLocation: ResolvedLocation(
        candidate: missing || online ? null : _area,
        source: missing || online
            ? LocationSource.unavailable
            : LocationSource.currentArea,
        precision: LocationPrecision.area,
        evidenceQuality: missing || online
            ? LocationEvidenceQuality.unresolved
            : LocationEvidenceQuality.assumed,
        reason: 'No venue supplied; using the device area.',
        resolvedAt: _now,
        observedAt: _now),
    assessment: online
        ? const EventWeatherAssessment(
            coverage: ForecastCoverage.online,
            impact: WeatherImpact.low,
            explanation: 'Online plan.')
        : missing
            ? const EventWeatherAssessment(
                coverage: ForecastCoverage.needsLocation,
                impact: WeatherImpact.unavailable,
                explanation: 'Choose one default city.')
            : coverage != null
                ? EventWeatherAssessment(
                    coverage: coverage,
                    impact: WeatherImpact.unavailable,
                    explanation: 'Weather is not available yet.')
                : unknownCondition
                    ? const EventWeatherAssessment(
                        coverage: ForecastCoverage.hourly,
                        impact: WeatherImpact.low,
                        explanation: 'Temperature available.',
                        minTemperatureC: 22,
                        maxTemperatureC: 24)
                    : _weather,
  );
}

/// UI contract fixture: resolver/network behavior is covered by controller tests.
class _Controller extends PlanCastController {
  _Controller(this.items)
      : super(
            weatherRepository: const FakeWeatherRepository(),
            platform: PlanCastPlatform(supported: false),
            clock: () => _now) {
    selectedCalendarIds = {'personal', 'work'};
    calendars = const [
      DeviceCalendar(id: 'personal', name: 'Personal'),
      DeviceCalendar(id: 'work', name: 'Work')
    ];
  }
  final List<PlanCastEventWeather> items;
  LocationCandidate? area = _area;
  LocationChoice? choice;
  LocationRuleScope? choiceScope;
  LocationCandidate? appliedArea;
  Set<String>? appliedCalendars;
  DateTime? appliedStart, appliedEnd;
  int undos = 0;
  bool undoable = false;
  String? searched;
  @override
  bool get supported => true;
  @override
  bool get connected => true;
  @override
  List<PlanCastEventWeather> get currentEvents => items;
  @override
  PlanCastDaySummary summaryForDay(DateTime day,
          {Set<String>? calendarFilter}) =>
      PlanCastDaySummary.build(
          day: day,
          now: _now,
          events: items,
          connected: true,
          selectedCalendarIds: selectedCalendarIds,
          calendarFilter: calendarFilter);
  @override
  PlanCastAgendaSummary summaryForRange(DateTime start,
          {int days = 7, Set<String>? calendarFilter}) =>
      PlanCastAgendaSummary(start: start, days: [
        for (var i = 0; i < days; i++)
          summaryForDay(DateTime(start.year, start.month, start.day + i),
              calendarFilter: calendarFilter)
      ]);

  @override
  LocationCandidate? get currentArea => area;
  @override
  bool get showSmartLocationExplanation => false;
  @override
  bool get canUndoLocationChange => undoable;
  @override
  Future<void> useCurrentArea({bool requestPermission = true}) async {
    area = _area;
    notifyListeners();
  }

  @override
  Future<void> setDefaultArea(LocationCandidate? value) async {
    smartLocations = smartLocations.copyWith(
        defaultArea: value, clearDefaultArea: value == null);
    notifyListeners();
  }

  @override
  Future<List<LocationCandidate>> searchVenues(String text) async {
    searched = text;
    return [_city];
  }

  @override
  List<PlanCastEventWeather> locationChoiceAffected(
          CalendarEvent event, LocationRuleScope scope) =>
      items
          .where((e) => scope == LocationRuleScope.calendarDefault
              ? e.event.calendarId == event.calendarId
              : e.event.id == event.id)
          .toList();
  @override
  Future<void> setLocationChoice(CalendarEvent event, LocationChoice choice,
      {LocationRuleScope scope = LocationRuleScope.occurrence}) async {
    this.choice = choice;
    choiceScope = scope;
    undoable = true;
    notifyListeners();
  }

  @override
  List<PlanCastEventWeather> batchAffected(
          {required DateTime start,
          required DateTime end,
          required Set<String> calendarIds}) =>
      items
          .where((e) =>
              !e.isOnline &&
              calendarIds.contains(e.event.calendarId) &&
              e.event.startUtc.isBefore(end) &&
              e.event.endUtc.isAfter(start))
          .toList();
  @override
  Future<void> applyTripArea(LocationCandidate area,
      {required DateTime start,
      required DateTime end,
      required Set<String> calendarIds}) async {
    appliedArea = area;
    appliedStart = start;
    appliedEnd = end;
    appliedCalendars = {...calendarIds};
    undoable = true;
    notifyListeners();
  }

  @override
  Future<void> undoLocationChange() async {
    undos++;
    undoable = false;
    notifyListeners();
  }
}

Future<void>? _fontLoading;
Future<void> _loadDaymakerFont() => _fontLoading ??= () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final entry = manifest
          .cast<Map<String, dynamic>>()
          .firstWhere((entry) => entry['family'] == 'DaymakerSans');
      final loader = FontLoader('DaymakerSans');
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }();

Future<void> _expectStat(WidgetTester tester, String label) async {
  final semantics = tester.ensureSemantics();
  try {
    await tester.pump();
    expect(find.bySemanticsLabel(label), findsOneWidget);
  } finally {
    semantics.dispose();
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _Controller c, Widget child,
      {bool dark = false, double scale = 1, double width = 320}) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      c.dispose();
    });
    await tester.runAsync(_loadDaymakerFont);
    await tester.pumpWidget(ChangeNotifierProvider<PlanCastController>.value(
        value: c,
        child: MaterialApp(
            theme: dark ? DMTheme.dark : DMTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true),
                child: child!),
            home: child)));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
        'Today preview and counts share today scope in ${dark ? 'dark' : 'light'} large text',
        (tester) async {
      final c = _Controller([
        _item('Tree trimming'),
        _item('Lunch'),
        _item('Tomorrow reservation', day: 17)
      ]);
      await pump(tester, c,
          const Scaffold(body: SingleChildScrollView(child: PlanCastCard())),
          dark: dark, scale: 1.8);
      expect(find.byType(PlanCastEventTile), findsNWidgets(2));
      expect(find.text('Tomorrow reservation'), findsNothing);
      await _expectStat(tester, '2 plans');
      await _expectStat(tester, '2 with weather');
      expect(
          find.textContaining('Overland Park · Your area'), findsNWidgets(2));
      expect(find.byType(DaymakerWeatherIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Online and unavailable weather do not render condition icons',
      (tester) async {
    final c = _Controller([
      _item('Online meeting', online: true),
      _item('Future plan', coverage: ForecastCoverage.tooEarly),
      _item('Only temperature', unknownCondition: true)
    ]);
    await pump(
        tester,
        c,
        Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          for (final item in c.items) PlanCastEventTile(item: item)
        ]))));
    expect(find.byType(DaymakerWeatherIcon), findsNothing);
    expect(find.text('Online · No venue weather needed'), findsOneWidget);
    expect(find.textContaining('Overland Park · Your area'), findsNWidgets(2));
    expect(planCastScopeSummary(c.items),
        '1 with weather · 2 automatically located · 1 online · 1 without weather');
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'briefing starts compact and expands in ${dark ? 'dark' : 'light'}',
        (tester) async {
      final c = _Controller([_item('Tree trimming'), _item('Lunch')]);
      await pump(tester, c, const PlanCastScreen(), dark: dark, width: 390);
      expect(find.byType(PlanCastBriefingCard), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Less'), findsNothing);
      expect(find.textContaining('You have 2 plans'), findsNothing);
      expect(find.text('Tree trimming').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Full readout'));
      await tester.pumpAndSettle();
      expect(find.text('Less'), findsOneWidget);
      final card = tester
          .widget<PlanCastBriefingCard>(find.byType(PlanCastBriefingCard));
      expect(find.text(card.readout.fullText), findsOneWidget);
      await tester.ensureVisible(find.text('Less'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Less'));
      await tester.pumpAndSettle();
      expect(find.text('Less'), findsNothing);
      await tester.scrollUntilVisible(find.text('Full readout'), -250);
      await tester.pumpAndSettle();
      expect(find.text('Full readout').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('main view declares Tomorrow and counts only that scope',
      (tester) async {
    final c = _Controller([
      _item('Today plan'),
      _item('Tomorrow plan', day: 17),
      _item('Later plan', day: 18),
    ]);
    await pump(tester, c, const PlanCastScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pumpAndSettle();
    await _expectStat(tester, '1 with weather');
    await tester.scrollUntilVisible(find.text('Tomorrow plan'), 250);
    expect(find.text('Today plan'), findsNothing);
    expect(find.text('Later plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stay details show dated segments without one aggregate icon',
      (tester) async {
    final original = _item('Three-day stay');
    final item = PlanCastEventWeather(
        event: original.event,
        resolvedLocation: original.resolvedLocation,
        venue: original.venue,
        venueTimeZone: 'America/Chicago',
        assessment: EventWeatherAssessment(
          coverage: ForecastCoverage.partial,
          impact: WeatherImpact.watch,
          explanation: 'Separate outlooks for your stay.',
          condition: 'Rain',
          weatherIcon: '10d',
          segments: [
            EventWeatherSegment(
                label: 'Arrival',
                startUtc: original.event.startUtc,
                endUtc: original.event.endUtc,
                assessment: _weather),
            EventWeatherSegment(
                label: 'Departure',
                startUtc: original.event.startUtc.add(const Duration(days: 2)),
                endUtc: original.event.endUtc.add(const Duration(days: 2)),
                assessment: const EventWeatherAssessment(
                    coverage: ForecastCoverage.tooEarly,
                    impact: WeatherImpact.unavailable,
                    explanation:
                        'Departure is outside the available forecast.')),
          ],
        ));
    final c = _Controller([item]);
    await pump(tester, c, Scaffold(body: PlanCastEventTile(item: item)));
    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(find.text('Arrival · Event forecast · Clear'), findsOneWidget);
    await tester.tap(find.text('Three-day stay'));
    await tester.pumpAndSettle();
    expect(find.text('Weather through your stay'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Departure'), 200);
    expect(find.text('Outside the available forecast.'), findsOneWidget);
    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stay dates distinguish DST full day from arrival at midnight',
      (tester) async {
    final midnight = DateTime.utc(2026, 11, 1, 4);
    final nextMidnight = DateTime.utc(2026, 11, 2, 5);
    expect(nextMidnight.difference(midnight), const Duration(hours: 25));
    final item = PlanCastEventWeather(
        event: CalendarEvent(
            id: 'dst-stay',
            nativeId: 'dst-stay',
            calendarId: 'personal',
            title: 'DST stay',
            startUtc: DateTime.utc(2026, 10, 31, 19),
            endUtc: DateTime.utc(2026, 11, 3, 5),
            timeZone: 'America/New_York'),
        venue: _city,
        venueTimeZone: 'America/New_York',
        assessment: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.low,
            explanation: 'Dated forecasts for your stay.',
            segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: DateTime.utc(2026, 10, 31, 19),
                  endUtc: midnight,
                  assessment: _weather),
              EventWeatherSegment(
                  label: 'Stay day',
                  startUtc: midnight,
                  endUtc: nextMidnight,
                  assessment: _weather),
              EventWeatherSegment(
                  label: 'Daily forecast',
                  startUtc: nextMidnight,
                  endUtc: DateTime.utc(2026, 11, 3, 5),
                  assessment: const EventWeatherAssessment(
                      coverage: ForecastCoverage.daily,
                      impact: WeatherImpact.low,
                      explanation: 'Broad daily forecast.')),
            ]));
    final c = _Controller([item]);
    await pump(tester, c, Scaffold(body: PlanCastEventTile(item: item)));
    await tester.tap(find.text('DST stay'));
    await tester.pumpAndSettle();
    expect(find.text('Sat, Oct 31 · 3:00 PM–midnight'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sun, Nov 1 · Full day'), 200);
    expect(find.text('Sun, Nov 1 · Full day'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mon, Nov 2 · Day outlook'), 200);
    expect(find.text('Mon, Nov 2 · Day outlook'), findsOneWidget);
    expect(find.textContaining('12:00 AM–12:00 AM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source sheet previews scope and applies a reusable saved place',
      (tester) async {
    final c = _Controller([_item('Tree trimming')]);
    c.smartLocations = SmartLocationState(savedPlaces: [
      SavedPlanCastPlace(
          id: 'home', label: 'Home', candidate: _area, createdAt: _now)
    ]);
    await pump(
        tester, c, Scaffold(body: PlanCastLocationRow(item: c.items.first)));
    await tester
        .tap(find.byKey(const ValueKey('plancast-location-Tree trimming')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply to…'));
    await tester.tap(find.text('Apply to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing-location events in this series'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 currently loaded plan affected'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Home'));
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('plancast-save-location')));
    await tester.tap(find.byKey(const ValueKey('plancast-save-location')));
    await tester.pumpAndSettle();
    expect(c.choiceScope, LocationRuleScope.seriesMissing);
    expect(c.choice?.kind, LocationChoiceKind.savedPlace);
    expect(c.choice?.savedPlaceId, 'home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one default city chooser sends only user city query',
      (tester) async {
    final c =
        _Controller([_item('Private tree trimming appointment', missing: true)])
          ..area = null;
    await pump(
        tester,
        c,
        Scaffold(
            body: SingleChildScrollView(
                child: PlanCastLocationNotice(items: c.items))));
    await tester.tap(find.text('Choose default city'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('plancast-city-query')), 'Miami Beach');
    await tester.tap(find.text('Find city'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miami Beach, US'));
    await tester.pumpAndSettle();
    expect(c.searched, 'Miami Beach');
    expect(c.defaultArea?.name, 'Miami Beach');
    expect(find.text('Choose default city'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch previews selected calendars and 48-hour window with Undo',
      (tester) async {
    final c = _Controller(
        [_item('Personal plan'), _item('Work plan', calendar: 'work')]);
    await pump(
        tester,
        c,
        Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      TextButton(
                          onPressed: () =>
                              reviewPlanCastBatch(context, c, _city),
                          child: const Text('Batch')),
                      PlanCastLocationNotice(items: c.items),
                    ]))));
    await tester.tap(find.text('Batch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 plans without a stronger location'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Work'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 plan without a stronger location'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Apply to 1 plan'));
    await tester.tap(find.text('Apply to 1 plan'));
    await tester.pumpAndSettle();
    expect(c.appliedCalendars, {'personal'});
    expect(
        c.appliedEnd!.difference(c.appliedStart!), const Duration(hours: 48));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.undos, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'default city is not offered as a fix for unresolved destinations or virtual plans',
      (tester) async {
    final c = _Controller([
      _item('Reservation at UNFRAMED, Miami Beach, Autograph Collection',
          missing: true),
      _item('Dinner',
          missing: true, locationText: '321 Unresolved Street, Unknown City'),
      _item('Video meeting', missing: true, locationText: 'Online'),
    ])
      ..area = null;
    await pump(
        tester, c, Scaffold(body: PlanCastLocationNotice(items: c.items)));
    expect(find.text('Choose default city'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'travel offers only configured Home and preserves the notice batch scope',
      (tester) async {
    final start = _now.add(const Duration(hours: 1));
    final end = start.add(const Duration(hours: 36));
    final c = _Controller(
        [_item('Personal plan'), _item('Work plan', calendar: 'work')]);
    c.travelNotice = TravelNotice(
        id: 'travel',
        area: _city,
        windowStart: start,
        windowEnd: end,
        calendarIds: const {'personal'},
        eventIds: const {'Personal plan'},
        createdAt: _now);
    await pump(
        tester,
        c,
        Scaffold(
            body: SingleChildScrollView(
                child: PlanCastLocationNotice(items: c.items))));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Use Home'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    c.smartLocations = c.smartLocations.copyWith(savedPlaces: [
      SavedPlanCastPlace(
          id: 'configured-home',
          label: 'Home',
          candidate: _area,
          createdAt: _now),
    ]);
    c.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 plan without a stronger location'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Apply to 1 plan'));
    await tester.tap(find.text('Apply to 1 plan'));
    await tester.pumpAndSettle();
    expect(c.appliedArea, _area);
    expect(c.appliedStart, start);
    expect(c.appliedEnd, end);
    expect(c.appliedCalendars, {'personal'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'event time respects DST and exclusive all-day dates without UTC clutter',
      (tester) async {
    final c = _Controller([]);
    final event = CalendarEvent(
        id: 'dst',
        nativeId: 'dst',
        calendarId: 'personal',
        title: 'DST plan',
        startUtc: DateTime.utc(2026, 3, 8, 6, 30),
        endUtc: DateTime.utc(2026, 3, 8, 7, 30),
        timeZone: 'America/New_York');
    final allDay = CalendarEvent(
        id: 'stay',
        nativeId: 'stay',
        calendarId: 'personal',
        title: 'Stay',
        startUtc: DateTime.utc(2026, 10, 16),
        endUtc: DateTime.utc(2026, 10, 19),
        timeZone: 'America/New_York',
        isAllDay: true,
        allDayStart: DateTime.utc(2026, 10, 16),
        allDayEnd: DateTime.utc(2026, 10, 19));
    await pump(
        tester,
        c,
        Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      Text(planCastEventTime(context, event,
                          now: DateTime.utc(2026, 3, 8, 5))),
                      Text(planCastEventTime(context, allDay, now: _now)),
                    ]))));
    expect(find.textContaining('Today · 1:30 AM–3:30 AM'), findsOneWidget);
    expect(
        find.textContaining('Today – Sun, Oct 18 · All day'), findsOneWidget);
    expect(find.textContaining('UTC'), findsNothing);
    expect(event.startUtc, DateTime.utc(2026, 3, 8, 6, 30));
    expect(event.endUtc, DateTime.utc(2026, 3, 8, 7, 30));
  });
}
