import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/data/daymaker_sample_data.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_current_weather_card.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_grid.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_metric_chips.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/models/precipitation_coverage.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/models/weather_safety.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/open_weather_repository.dart';
import 'package:grumpy_skies/services/cache_service.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';
import 'package:grumpy_skies/shared/widgets/weather_safety_banner.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';

final _now = DateTime.utc(2026, 9, 17, 12);
final _location = WeatherLocation(
    name: 'Test City',
    country: 'US',
    latitude: 40,
    longitude: -90,
    updatedAt: _now);

WeatherBundle _weather(
    {DateTime? observedAt,
    DateTime? fetchedAt,
    bool verified = false,
    DateTime? checkedAt,
    List<WeatherAlert> alerts = const []}) {
  final base = WeatherBundle.fromSnapshot(DayMakerSampleData.weatherSnapshot);
  return WeatherBundle.fromJson({
    ...base.toJson(),
    'current': {
      ...base.current.toJson(),
      'lastUpdated': (observedAt ?? _now).toIso8601String(),
      'sourceUpdatedAt': (observedAt ?? _now).toIso8601String(),
      'fetchedAt': (fetchedAt ?? _now).toIso8601String(),
      'latitude': 40.0,
      'longitude': -90.0
    },
    'alertCoverageVerified': verified,
    'alertsCheckedAt': checkedAt?.toIso8601String(),
    'alerts': alerts.map((alert) => alert.toJson()).toList(),
  });
}

void main() {
  test(
      'retrieval cannot reset observation; old and future timestamps fail closed',
      () {
    final old = _weather(
        observedAt: _now.subtract(const Duration(days: 3)),
        fetchedAt: _now,
        verified: true,
        checkedAt: _now);
    expect(
        old.current.displayUpdatedAt, _now.subtract(const Duration(days: 3)));
    expect(weatherFreshness(old.current.displayUpdatedAt, _now),
        WeatherFreshness.stale);
    expect(weatherSafetyStatus(old, _now), WeatherSafetyStatus.stale);
    final future = _weather(
        observedAt: _now.add(const Duration(hours: 3)),
        verified: true,
        checkedAt: _now);
    expect(weatherFreshness(future.current.displayUpdatedAt, _now),
        WeatherFreshness.future);
    expect(weatherSafetyStatus(future, _now), WeatherSafetyStatus.stale);
  });

  test(
      'coverage absent, stale, offline, future and active alerts block clear status',
      () {
    expect(weatherSafetyStatus(_weather(), _now), WeatherSafetyStatus.unknown);
    final clear = _weather(verified: true, checkedAt: _now);
    expect(weatherSafetyStatus(clear, _now), WeatherSafetyStatus.clear);
    expect(weatherSafetyStatus(clear, _now.add(const Duration(minutes: 11))),
        WeatherSafetyStatus.stale);
    expect(weatherSafetyStatus(clear.asOfflineCache(), _now),
        WeatherSafetyStatus.stale);
    expect(
        weatherSafetyStatus(
            _weather(
                verified: true,
                checkedAt: _now.add(const Duration(minutes: 1))),
            _now),
        WeatherSafetyStatus.stale);
    expect(
        weatherSafetyStatus(
            _weather(alerts: [
              WeatherAlert(
                  senderName: 'NWS',
                  event: 'Tornado warning',
                  description: 'Take shelter',
                  end: _now.add(const Duration(hours: 1)))
            ]),
            _now),
        WeatherSafetyStatus.activeAlert);
  });

  test(
      'location and device clock changes invalidate safety; resume retains warnings',
      () async {
    var clock = _now;
    final controller = WeatherLocationController(
        repository: const FakeWeatherRepository(),
        initialLocation: _location,
        clock: () => clock);
    addTearDown(controller.dispose);
    controller.updateWeatherSafety(
        _weather(verified: true, checkedAt: _now), _location);
    expect(controller.safetyStatus, WeatherSafetyStatus.clear);
    clock = _now.subtract(const Duration(minutes: 1));
    expect(controller.safetyStatus, WeatherSafetyStatus.stale);
    clock = _now;
    controller.invalidateWeatherSafety();
    expect(controller.safetyStatus, WeatherSafetyStatus.stale);
    final warning = WeatherAlert(
        senderName: 'NWS',
        event: 'Warning',
        description: 'Shelter',
        end: _now.add(const Duration(hours: 1)));
    controller.updateWeatherSafety(_weather(alerts: [warning]), _location);
    controller.markWeatherError('Offline');
    expect(controller.activeAlerts.single.description, 'Shelter');
    expect(controller.safetyStatus, WeatherSafetyStatus.activeAlert);
    await controller.selectLocation(const LocationCandidate(
        name: 'Other', country: 'US', lat: 41, lon: -91, source: 'city'));
    expect(controller.safetyStatus, WeatherSafetyStatus.unknown);
    expect(controller.activeAlerts, isEmpty);
    controller.updateWeatherSafety(
        _weather(verified: true, checkedAt: _now), _location);
    expect(controller.safetyStatus, WeatherSafetyStatus.unknown);
  });

  test('minute claims use continuous timestamps and preserve missing values',
      () {
    List<MinutePrecipitation> points(int count, {int start = 0}) =>
        List.generate(
            count,
            (i) => MinutePrecipitation(
                time: _now.add(Duration(minutes: i + start)),
                precipitation: 0));
    expect(PrecipitationCoverage([], _now).summary(_now),
        'Precipitation forecast unavailable');
    expect(
        PrecipitationCoverage(points(60, start: -120), _now).points, isEmpty);
    expect(PrecipitationCoverage(points(60, start: 10), _now).coversNextHour,
        isFalse);
    expect(PrecipitationCoverage(points(59), _now).summary(_now),
        startsWith('Partial forecast'));
    expect(PrecipitationCoverage(points(60), _now).coversNextHour, isTrue);
    expect(
        PrecipitationCoverage([...points(20), ...points(40, start: 21)], _now)
            .coversNextHour,
        isFalse);
    expect(
        PrecipitationCoverage(List.filled(60, points(1).single), _now)
            .coversNextHour,
        isFalse);
    expect(PrecipitationCoverage(points(60), _now, unavailable: true).points,
        isEmpty);
    final missing = MinutePrecipitation.fromJson(
        {'dt': _now.millisecondsSinceEpoch / 1000});
    expect(missing.hasValue, isFalse);
    expect(missing.toJson()['precipitation'], isNull);
    final wet = PrecipitationCoverage([
      MinutePrecipitation(
          time: _now.add(const Duration(minutes: 12)), precipitation: 0.1)
    ], _now);
    expect(wet.summary(_now),
        'Partial forecast: precipitation expected in 12 min');
  });

  test(
      'backend preserves alert metadata and never supplies current time for absent observation',
      () async {
    final client = OpenWeatherBackendClient(
        baseUrl: 'https://weather.invalid',
        httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'current': {'temp': 72, 'units': 'imperial'},
              'alerts': [
                {
                  'senderName': 'Official NWS',
                  'event': 'Flood warning',
                  'area': 'River district',
                  'instructions': 'Move to higher ground',
                  'start': 1789632000,
                  'end': 1789635600,
                  'description': 'Flooding is occurring'
                }
              ],
              'alertCoverageVerified': true,
              'alertsCheckedAt': _now.toIso8601String()
            }),
            200,
            headers: {'content-type': 'application/json'})));
    final result = await client.forecast(latitude: 40, longitude: -90);
    expect(result.current.lastUpdated.millisecondsSinceEpoch, 0);
    final persisted = WeatherBundle.fromJson(result.toJson());
    expect(persisted.alerts.single.area, 'River district');
    expect(persisted.alerts.single.instructions, 'Move to higher ground');
    expect(persisted.alerts.single.start, isNotNull);
    expect(persisted.alerts.single.end, isNotNull);
    expect(persisted.alertCoverageVerified, isTrue);
    expect(weatherSafetyStatus(persisted, _now), WeatherSafetyStatus.stale);
  });

  test(
      'offline repository fallback preserves observed and fetched times and marks cached',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = await CacheService.create(
        clock: () => _now.subtract(const Duration(hours: 1)));
    final original = _weather(
        observedAt: _now.subtract(const Duration(hours: 2)),
        fetchedAt: _now.subtract(const Duration(hours: 1)),
        verified: true,
        checkedAt: _now);
    await cache.saveWeatherBundle(lat: 40, lon: -90, bundle: original);
    final repository = OpenWeatherRepository(
        clock: () => _now,
        cacheService: cache,
        client: OpenWeatherBackendClient(
            baseUrl: 'https://weather.invalid',
            httpClient: MockClient(
                (_) async => throw http.ClientException('offline'))));
    final result = await repository.getWeather(
        latitude: 40, longitude: -90, location: _location);
    expect(result.isOfflineCache, isTrue);
    expect(result.current.displayUpdatedAt, original.current.displayUpdatedAt);
    expect(result.current.fetchedAt, original.current.fetchedAt);
    expect(weatherSafetyStatus(result, _now), WeatherSafetyStatus.stale);
  });

  test(
      'roast display tokens convert, while matching thresholds remain Fahrenheit',
      () {
    final context = WeatherRoastContext.fromWeatherBundle(_weather(),
        now: _now, temperatureUnit: TemperatureUnit.celsius);
    expect(context.tempF, 72);
    expect(context.render('{temp}{temp_unit}; feels {feels_like}{temp_unit}'),
        '22°C; feels 23°C');
  });

  testWidgets('future observation never appears just observed', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
            body: ForecastCurrentWeatherCard(
                weather: _weather(observedAt: _now.add(const Duration(days: 1)))
                    .current,
                now: _now))));
    await tester.pumpAndSettle();
    expect(find.text('Observation timestamp is ahead of device clock'),
        findsOneWidget);
    expect(find.text('Observed just now'), findsNothing);
  });

  testWidgets(
      'late weather from previous location cannot replace selected location',
      (tester) async {
    final repository = _DeferredRepository();
    final controller = WeatherLocationController(
        repository: repository, initialLocation: _location, clock: () => _now);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: DMTheme.light,
            home: ForecastScreen(
                weatherRepository: repository, clock: () => _now))));
    await tester.pump();
    expect(repository.requests.length, 1);
    await controller.selectLocation(const LocationCandidate(
        name: 'Other City', country: 'US', lat: 41, lon: -91, source: 'city'));
    await tester.pump();
    expect(repository.requests.length, 2);
    final newWeather = _weather(verified: true, checkedAt: _now);
    repository.requests.last.complete(WeatherBundle.fromJson({
      ...newWeather.toJson(),
      'current': {
        ...newWeather.current.toJson(),
        'locationName': 'Other City',
        'latitude': 41.0,
        'longitude': -91.0
      }
    }));
    await tester.pumpAndSettle();
    expect(find.text('Other City'), findsOneWidget);
    expect(controller.safetyStatus, WeatherSafetyStatus.clear);
    repository.requests.first.complete(_weather(alerts: [
      const WeatherAlert(
          senderName: 'NWS',
          event: 'Old city warning',
          description: 'Wrong area')
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Other City'), findsOneWidget);
    expect(find.text('Old city warning'), findsNothing);
    expect(controller.safetyStatus, WeatherSafetyStatus.clear);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
      'shared warning stays readable at small width and large text; details set modal gate',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = WeatherLocationController(
        repository: const FakeWeatherRepository(),
        initialLocation: _location,
        clock: () => _now);
    controller.updateWeatherSafety(
        _weather(alerts: [
          WeatherAlert(
              senderName: 'National Weather Service',
              event: 'Severe thunderstorm warning with long name',
              area: 'Test County',
              instructions: 'Take shelter indoors.',
              description: 'Stay away from windows.',
              end: _now.add(const Duration(hours: 1)))
        ]),
        _location);
    final modal = <bool>[];
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: DMTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!),
            home: Scaffold(
                body: Column(children: [
              WeatherSafetyBanner(onModalChanged: modal.add),
              const Expanded(child: Center(child: Text('Weather content')))
            ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(modal, [true]);
    expect(find.text('Source: National Weather Service'), findsOneWidget);
    expect(find.text('Take shelter indoors.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close alert details'));
    await tester.pumpAndSettle();
    expect(modal, [true, false]);
    await tester.tap(find.byTooltip('Collapse alert summary'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('1 weather alert'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('current and all forecast values convert for Celsius preference',
      (tester) async {
    final settings = SettingsController();
    settings.setTemperatureUnit(TemperatureUnit.celsius);
    final weather = _weather();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
            theme: DMTheme.light,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Column(children: [
              ForecastCurrentWeatherCard(weather: weather.current, now: _now),
              ForecastMetricChips(weather: weather.snapshot!),
              ForecastHourlyStrip(hourly: [
                HourlyForecast(time: _now, temperatureC: 10, condition: 'Clear')
              ], referenceTime: _now),
              ForecastDailyGrid(daily: [
                DailyForecast(
                    date: _now, minTempC: 5, maxTempC: 20, condition: 'Clear')
              ], referenceTime: _now),
            ]))))));
    await tester.pumpAndSettle();
    expect(find.text('22°C'), findsOneWidget);
    expect(find.text('23°'), findsWidgets);
    expect(find.text('10°'), findsOneWidget);
    expect(find.text('20° / 5°'), findsOneWidget);
    expect(find.text('72°F'), findsNothing);
    settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    await tester.pumpAndSettle();
    expect(find.text('72°F'), findsOneWidget);
    expect(find.text('50°'), findsOneWidget);
    expect(find.text('68° / 41°'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh ad-like pause and resume does not request extra weather',
      (tester) async {
    var clock = _now;
    final repository =
        _BundleRepository(_weather(verified: true, checkedAt: _now));
    final controller = WeatherLocationController(
        repository: repository, initialLocation: _location, clock: () => clock);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: DMTheme.light,
            home: ForecastScreen(
                weatherRepository: repository, clock: () => clock))));
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(controller.safetyStatus, WeatherSafetyStatus.clear);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('old weather stays old after app resume and fresh retrieval',
      (tester) async {
    var clock = _now;
    final repository = _BundleRepository(
        _weather(observedAt: _now.subtract(const Duration(days: 2))));
    final controller = WeatherLocationController(
        repository: repository, initialLocation: _location, clock: () => clock);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: DMTheme.light,
            home: ForecastScreen(
                weatherRepository: repository, clock: () => clock))));
    await tester.pumpAndSettle();
    expect(find.text('Observed 48 hours ago · Stale'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = clock.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Observed 49 hours ago · Stale'), findsOneWidget);
    expect(repository.requests, 2);
    await tester.pump();
    expect(repository.requests, 2, reason: 'Rebuilds do not fetch weather');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('official warnings precede conditions and suppress comedy',
      (tester) async {
    final repository = _BundleRepository(_weather(alerts: [
      WeatherAlert(
          senderName: 'National Weather Service',
          event: 'Tornado Warning',
          area: 'Test County',
          instructions: 'Take shelter now.',
          description: 'A tornado was reported.',
          start: _now.subtract(const Duration(minutes: 5)),
          end: _now.add(const Duration(hours: 1)))
    ]));
    final controller = WeatherLocationController(
        repository: repository, initialLocation: _location, clock: () => _now);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: DMTheme.light,
            home: ForecastScreen(
                weatherRepository: repository, clock: () => _now))));
    await tester.pumpAndSettle();
    expect(find.text('Take shelter now.'), findsOneWidget);
    expect(find.text('Area: Test County'), findsOneWidget);
    expect(find.textContaining('National Weather Service'), findsOneWidget);
    expect(
        tester.getTopLeft(find.byType(WeatherAlertsPanel)).dy,
        lessThan(
            tester.getTopLeft(find.byType(ForecastCurrentWeatherCard)).dy));
    expect(find.byType(ForecastRoastCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

class _BundleRepository extends FakeWeatherRepository {
  _BundleRepository(this.bundle);
  final WeatherBundle bundle;
  int requests = 0;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    requests++;
    return bundle;
  }
}

class _DeferredRepository extends FakeWeatherRepository {
  final requests = <Completer<WeatherBundle>>[];
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) {
    final request = Completer<WeatherBundle>();
    requests.add(request);
    return request.future;
  }
}
