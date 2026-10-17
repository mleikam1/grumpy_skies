import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_presentation.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';

final _now = DateTime(2026, 10, 17, 8);
const _city = LocationCandidate(
    name: 'Miami Beach',
    country: 'US',
    lat: 25.79,
    lon: -80.13,
    source: 'city');
const _clear = EventWeatherAssessment(
    coverage: ForecastCoverage.hourly,
    impact: WeatherImpact.low,
    explanation: 'Clear during the event.',
    condition: 'Clear',
    weatherIcon: '01d',
    minTemperatureC: 20,
    maxTemperatureC: 20.1,
    peakPrecipitationChance: 0,
    maxWindKph: 8);
const _rain = EventWeatherAssessment(
    coverage: ForecastCoverage.hourly,
    impact: WeatherImpact.watch,
    explanation: 'Rain in this event window.',
    condition: 'Rain',
    weatherIcon: '10d',
    minTemperatureC: 23,
    maxTemperatureC: 25,
    peakPrecipitationChance: 70,
    advice: 'Bring a rain layer.');

PlanCastEventWeather _plan(String id,
    {String calendar = 'personal',
    int day = 17,
    bool online = false,
    EventWeatherAssessment weather = _clear,
    bool stay = false,
    String? title}) {
  final start = DateTime(2026, 10, day, 11).toUtc();
  return PlanCastEventWeather(
    event: CalendarEvent(
        id: id,
        nativeId: id,
        calendarId: calendar,
        title: title ?? id,
        startUtc: start,
        endUtc: stay
            ? DateTime(2026, 10, day + 2, 15).toUtc()
            : start.add(const Duration(hours: 1)),
        timeZone: 'America/Chicago'),
    venue: online ? null : _city,
    venueTimeZone: 'America/Chicago',
    participation:
        online ? EventParticipation.online : EventParticipation.physical,
    resolvedLocation: online
        ? null
        : ResolvedLocation(
            candidate: _city,
            source: LocationSource.inferredCity,
            precision: LocationPrecision.city,
            evidenceQuality: LocationEvidenceQuality.supported,
            reason: 'City from invite.',
            resolvedAt: _now),
    assessment: online
        ? const EventWeatherAssessment(
            coverage: ForecastCoverage.online,
            impact: WeatherImpact.low,
            explanation: 'Online plan.')
        : weather,
  );
}

class _CountingWeather extends FakeWeatherRepository {
  int requests = 0;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) {
    requests++;
    return super.getWeather(
        latitude: latitude,
        longitude: longitude,
        location: location,
        forceRefresh: forceRefresh);
  }
}

class _Controller extends PlanCastController {
  _Controller(this.items, _CountingWeather repository)
      : super(
            weatherRepository: repository,
            platform: PlanCastPlatform(supported: false),
            clock: () => _now) {
    selectedCalendarIds = {'personal', 'work', 'family', 'shared'};
    calendars = const [
      DeviceCalendar(id: 'personal', name: 'Personal', colorArgb: 0xFF258D87),
      DeviceCalendar(id: 'work', name: 'Work'),
      DeviceCalendar(id: 'family', name: 'Family'),
      DeviceCalendar(id: 'shared', name: 'Shared plans')
    ];
  }
  final List<PlanCastEventWeather> items;
  @override
  bool get supported => true;
  @override
  bool get connected => true;
  @override
  bool get showSmartLocationExplanation => false;
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
  List<HourlyForecast> cachedHoursForEvent(PlanCastEventWeather item) =>
      item.isOnline
          ? []
          : [
              HourlyForecast(
                  time: item.event.startUtc,
                  temperatureC: 20,
                  condition: 'Clear',
                  weatherIcon: '01d'),
              HourlyForecast(
                  time: item.event.startUtc.add(const Duration(hours: 1)),
                  temperatureC: 21,
                  condition: 'Clear',
                  weatherIcon: '01d'),
            ];
}

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
      {bool dark = false,
      double width = 390,
      double scale = 1,
      SettingsController? settings}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      c.dispose();
    });
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlanCastController>.value(value: c),
          if (settings != null)
            ChangeNotifierProvider<SettingsController>.value(value: settings),
        ],
        child: MaterialApp(
            theme: dark ? DMTheme.dark : DMTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: child)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'day filter changes scope without mutating four imported calendars or loading weather',
      (tester) async {
    final repo = _CountingWeather();
    final c = _Controller([
      _plan('Morning workout'),
      _plan('Standup', calendar: 'work', online: true),
      _plan('Tomorrow hotel', day: 18, weather: _rain)
    ], repo);
    await pump(tester, c, const PlanCastScreen());
    await _expectStat(tester, '2 plans');
    final firstReadout = tester
        .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
        .readout;
    await tester.tap(find.byKey(const ValueKey('plancast-agenda-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Work'));
    await tester.pumpAndSettle();
    await _expectStat(tester, '1 plans');
    expect(c.selectedCalendarIds, {'personal', 'work', 'family', 'shared'});
    expect(
        tester
            .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
            .readout
            .signature,
        isNot(firstReadout.signature));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('No plans in this agenda filter'), findsOneWidget);
    expect(repo.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'weekly rows group a stay by date while total counts unique occurrences',
      (tester) async {
    final start = DateTime(2026, 10, 17, 11).toUtc();
    final stay = _plan('Hotel reservation',
        stay: true,
        weather: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.watch,
            explanation: 'Dated stay forecasts.',
            segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: start,
                  endUtc: DateTime(2026, 10, 18).toUtc(),
                  assessment: _rain),
              EventWeatherSegment(
                  label: 'Stay',
                  startUtc: DateTime(2026, 10, 18).toUtc(),
                  endUtc: DateTime(2026, 10, 19).toUtc(),
                  assessment: _clear),
              EventWeatherSegment(
                  label: 'Departure',
                  startUtc: DateTime(2026, 10, 19).toUtc(),
                  endUtc: DateTime(2026, 10, 19, 15).toUtc(),
                  assessment: _clear),
            ]));
    final c = _Controller(
        [stay, _plan('Online standup', online: true, day: 18)],
        _CountingWeather());
    await pump(tester, c, const PlanCastScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'This week'));
    await tester.pumpAndSettle();
    await _expectStat(tester, '2 plans');
    expect(find.textContaining('This week ·'), findsOneWidget);
    final range = c.summaryForRange(_now);
    expect(range.events.length, 2);
    expect(
        range.days.take(3).map(
            (d) => d.events.where((e) => e.event.id == stay.event.id).length),
        [1, 1, 1]);
    await tester.scrollUntilVisible(
        find.byKey(ValueKey(
            'agenda-${DateTime(2026, 10, 18).toIso8601String()}-${stay.event.id}')),
        300);
    final row = tester.widget<PlanCastEventTile>(find.byKey(ValueKey(
        'agenda-${DateTime(2026, 10, 18).toIso8601String()}-${stay.event.id}')));
    expect(row.item.assessment.condition, 'Clear');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stay preview labels today and uses the available dated segment',
      (tester) async {
    final day = DateTime(2026, 10, 17);
    final plan = _plan('Stay reservation',
        stay: true,
        weather: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.low,
            explanation: 'Partial dated coverage.',
            segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: day.toUtc(),
                  endUtc: DateTime(2026, 10, 17, 10).toUtc(),
                  assessment: const EventWeatherAssessment(
                      coverage: ForecastCoverage.unavailable,
                      impact: WeatherImpact.unavailable,
                      explanation: 'Arrival hours unavailable.')),
              EventWeatherSegment(
                  label: 'Stay day',
                  startUtc: DateTime(2026, 10, 17, 10).toUtc(),
                  endUtc: DateTime(2026, 10, 18).toUtc(),
                  assessment: _clear),
            ]));
    final c = _Controller([plan], _CountingWeather());
    await pump(tester, c,
        Scaffold(body: PlanCastEventTile(item: plan, compact: true, day: day)));
    expect(find.text('Today outlook'), findsOneWidget);
    expect(find.text('68°'), findsOneWidget);
    expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'compact rows preserve title, units, online status in ${dark ? 'dark' : 'light'} large text',
        (tester) async {
      final repo = _CountingWeather();
      final physical = _plan('hotel',
          title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection');
      final online = _plan('Online meeting', online: true);
      final c = _Controller([physical, online], repo);
      final settings = SettingsController()
        ..setTemperatureUnit(TemperatureUnit.celsius);
      addTearDown(settings.dispose);
      await pump(
          tester,
          c,
          Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
            PlanCastEventTile(item: physical, compact: true),
            PlanCastEventTile(item: online, compact: true),
          ]))),
          dark: dark,
          width: 360,
          scale: 1.8,
          settings: settings);
      expect(find.text(physical.event.title), findsOneWidget);
      expect(find.text('20°'), findsOneWidget);
      expect(find.textContaining('20°–20°'), findsNothing);
      expect(find.text('Online · No venue weather needed'), findsOneWidget);
      expect(find.byType(DaymakerWeatherIcon), findsOneWidget);
      expect(find.text('Change'), findsNothing);
      expect(repo.requests, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'details expose actual weather and alerts while metadata stays collapsed',
      (tester) async {
    const weather = EventWeatherAssessment(
        coverage: ForecastCoverage.hourly,
        impact: WeatherImpact.disruption,
        explanation: 'Official warning applies.',
        condition: 'Rain',
        weatherIcon: '10d',
        minTemperatureC: 23,
        maxTemperatureC: 25,
        peakPrecipitationChance: 80,
        maxWindKph: 30,
        alerts: [
          WeatherAlert(
              senderName: 'Weather authority',
              event: 'Flood Warning',
              description: 'Avoid flooded roads.',
              instructions: 'Follow local instructions.')
        ]);
    final plan = _plan('Keep this real event title', weather: weather);
    final repo = _CountingWeather();
    final c = _Controller([plan], repo);
    await pump(tester, c, Scaffold(body: PlanCastEventTile(item: plan)));
    await tester.tap(find.text(plan.event.title));
    await tester.pumpAndSettle();
    expect(find.text('Event details'), findsOneWidget);
    expect(find.text('73°F–77°F'), findsOneWidget);
    expect(find.text('Hourly forecast'), findsOneWidget);
    expect(find.text('Location source: local'), findsNothing);
    final vertical = find.byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(find.text('Flood Warning'), 250,
        scrollable: vertical);
    expect(find.text('Avoid flooded roads.'), findsOneWidget);
    expect(find.text('Follow local instructions.'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Weather data © OpenWeather'), 200,
        scrollable: vertical);
    expect(find.text('Weather data © OpenWeather'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('More details'), 200,
        scrollable: vertical);
    await tester.ensureVisible(find.text('More details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.text('Location source: local'), findsOneWidget);
    expect(repo.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('persona remains selected across day tabs and rebuilds',
      (tester) async {
    final repo = _CountingWeather();
    final c = _Controller(
        [_plan('Today'), _plan('Tomorrow rain', day: 18, weather: _rain)],
        repo);
    final settings = SettingsController()..setSelectedPersonaId('grandpa');
    addTearDown(settings.dispose);
    await pump(tester, c, const PlanCastScreen(),
        settings: settings, width: 430);
    final today = tester
        .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
        .readout;
    expect(
        tester
            .widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait))
            .personaId,
        'grandpa');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
    await tester.pumpAndSettle();
    final tomorrow = tester
        .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
        .readout;
    expect(tomorrow.personaId, today.personaId);
    expect(tomorrow.signature, isNot(today.signature));
    c.notifyListeners();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
            .readout
            .text,
        tomorrow.text);
    expect(repo.requests, 0);
  });
}
