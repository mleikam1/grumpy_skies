import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/event_weather_evaluator.dart';
import 'package:grumpy_skies/features/plancast/plancast_models.dart';
import 'package:grumpy_skies/features/plancast/venue_weather_repository.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/open_weather_repository.dart';
import 'package:grumpy_skies/services/cache_service.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plancast_core_test.dart' as fixture;

WeatherBundle _weather(DateTime updated,
        {String zone = 'America/Chicago',
        List<HourlyForecast> hourly = const [],
        List<DailyForecast> daily = const []}) =>
    WeatherBundle(
        current: CurrentWeather.fromJson({
          ...fixture.weather().current.toJson(),
          'lastUpdated': updated.toIso8601String(),
          'sourceUpdatedAt': updated.toIso8601String(),
          'timezone': zone,
        }),
        hourly: hourly,
        daily: daily);

CalendarEvent _stay(DateTime start, DateTime end, {bool allDay = false}) =>
    CalendarEvent(
        id: 'stay',
        nativeId: 'stay',
        calendarId: 'work',
        title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection',
        startUtc: start,
        endUtc: end,
        timeZone: 'America/New_York',
        isAllDay: allDay,
        allDayStart: allDay ? start : null,
        allDayEnd: allDay ? end : null);

DailyForecast _day(int day, {String condition = 'Clear'}) => DailyForecast(
    date: DateTime.utc(2026, 10, day),
    minTempC: 18,
    maxTempC: 24,
    condition: condition,
    precipitationChance: condition == 'Clear' ? 10 : 80,
    weatherIcon: condition == 'Clear' ? '01d' : '11d');

class _Backend extends OpenWeatherBackendClient {
  _Backend() : super(baseUrl: 'https://weather.invalid');
  int requests = 0;
  Completer<WeatherBundle>? gate;
  @override
  Future<LocationCandidate> reverse(
          {required double latitude, required double longitude}) async =>
      LocationCandidate(
          name: 'Area',
          country: '',
          lat: latitude,
          lon: longitude,
          source: 'test');
  @override
  Future<WeatherBundle> forecast(
      {required double latitude,
      required double longitude,
      String units = 'imperial',
      String locationName = ''}) async {
    requests++;
    return gate?.future ?? Future.value(fixture.weather());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'unrelated': 'keep'}));
  const evaluator = EventWeatherEvaluator();
  test(
      'hotel stay has separate arrival, stay and departure with no aggregate storm icon',
      () {
    final event =
        _stay(DateTime.utc(2026, 10, 15, 22), DateTime.utc(2026, 10, 17, 16));
    final result = evaluator.evaluate(
        event: event,
        weather: _weather(fixture.now,
            zone: 'America/New_York',
            daily: [_day(15), _day(16, condition: 'Thunderstorm'), _day(17)]),
        now: fixture.now,
        isStay: true);
    expect(result.segments.map((s) => s.label),
        ['Arrival', 'Stay day', 'Departure']);
    expect(result.segments.first.startUtc, event.startUtc);
    expect(result.segments.last.endUtc, event.endUtc);
    expect(result.segments.map((s) => s.assessment.condition),
        ['Clear', 'Thunderstorm', 'Clear']);
    expect(result.condition, 'Unknown');
    expect(result.weatherIcon, isNull);
    expect(result.coverage, ForecastCoverage.daily);
    expect(result.arrival, isNotNull);
    expect(result.leaving, isNotNull);
  });
  test('all-day stay uses civil exclusive end without invented checkout time',
      () {
    final result = evaluator.evaluate(
        event: _stay(DateTime.utc(2026, 10, 15), DateTime.utc(2026, 10, 18),
            allDay: true),
        weather: _weather(fixture.now,
            zone: 'Pacific/Honolulu', daily: [_day(15), _day(16), _day(17)]),
        now: fixture.now,
        isStay: true);
    expect(result.segments, hasLength(3));
    expect(result.segments.map((s) => s.startUtc.day), [15, 16, 17]);
    expect(result.segments.last.endUtc, DateTime.utc(2026, 10, 18));
    expect(result.uncertainties.join(), contains('do not specify arrival'));
    expect(result.arrival, isNull);
  });
  test('stay crossing DST fall-back covers 25 real hours on transition date',
      () {
    final now = DateTime.utc(2026, 10, 31, 20);
    final start = DateTime.utc(2026, 10, 31, 22),
        end = DateTime.utc(2026, 11, 2, 18);
    final result = evaluator.evaluate(
        event: _stay(start, end),
        weather: _weather(now, hourly: [
          for (var i = 0; i < 55; i++)
            HourlyForecast(
                time: now.add(Duration(hours: i)),
                temperatureC: 15,
                condition: 'Clear',
                precipitationChance: 5)
        ]),
        now: now,
        isStay: true);
    expect(result.segments, hasLength(3));
    expect(result.segments[1].endUtc.difference(result.segments[1].startUtc),
        const Duration(hours: 25));
    expect(result.segments.first.startUtc, start);
    expect(result.segments.last.endUtc, end);
    expect(result.coverage, ForecastCoverage.hourly);
  });
  test('partial stay keeps daily granularity and out-of-horizon date separate',
      () {
    final result = evaluator.evaluate(
        event: _stay(
            DateTime.utc(2026, 10, 15, 22), DateTime.utc(2026, 10, 18, 16)),
        weather: _weather(fixture.now, daily: [_day(15), _day(16)]),
        now: fixture.now,
        isStay: true);
    expect(result.coverage, ForecastCoverage.partial);
    expect(result.isDaily, isTrue);
    expect(result.segments.last.assessment.coverage, ForecastCoverage.tooEarly);
    expect(result.segments.last.assessment.weatherIcon, isNull);
  });
  test('stale stay has no detailed condition icon or fresh segment', () {
    final result = evaluator.evaluate(
        event: _stay(DateTime.utc(2026, 10, 15), DateTime.utc(2026, 10, 18),
            allDay: true),
        weather: _weather(fixture.now.subtract(const Duration(hours: 7)),
            daily: [_day(15)]),
        now: fixture.now,
        isStay: true);
    expect(result.coverage, ForecastCoverage.stale);
    expect(result.usable, isFalse);
    expect(result.weatherIcon, isNull);
    expect(result.segments, isEmpty);
  });
  test(
      'private forecast coordinates never enter public persistent weather cache',
      () async {
    final cache = await CacheService.create(clock: () => fixture.now);
    final backend = _Backend();
    final public = OpenWeatherRepository(
        client: backend, cacheService: cache, clock: () => fixture.now);
    final private = VenueWeatherRepository(public, clock: () => fixture.now);
    const point = LocationCandidate(
        name: 'Private venue',
        country: '',
        lat: 25.79,
        lon: -80.13,
        source: 'user');
    await private.get(point);
    expect(backend.requests, 1);
    expect(cache.getWeatherBundle(point.lat, point.lon), isNull);
    private.clear();
    expect((await SharedPreferences.getInstance()).getKeys(), {'unrelated'});
    await public.getWeather(latitude: 41, longitude: -87);
    expect(cache.getWeatherBundle(41, -87), isNotNull);
    expect(
        (await SharedPreferences.getInstance()).getString('unrelated'), 'keep');
  });
  test(
      'private consumer reuses compatible public cache and shared in-flight work',
      () async {
    final cache = await CacheService.create(clock: () => fixture.now);
    final backend = _Backend()..gate = Completer<WeatherBundle>();
    final public = OpenWeatherRepository(
        client: backend, cacheService: cache, clock: () => fixture.now);
    final private = public.privateLocationConsumer();
    final first = private.getWeather(latitude: 41, longitude: -87);
    await Future<void>.delayed(Duration.zero);
    final second = public.getWeather(latitude: 41, longitude: -87);
    await Future<void>.delayed(Duration.zero);
    expect(backend.requests, 1);
    backend.gate!.complete(fixture.weather());
    await Future.wait([first, second]);
    expect(cache.getWeatherBundle(41, -87), isNull,
        reason: 'Private-owned work does not persist through a public waiter.');
    backend.gate = null;
    await public.getWeather(latitude: 41, longitude: -87);
    final count = backend.requests;
    await private.getWeather(latitude: 41, longitude: -87);
    expect(backend.requests, count);
    expect(cache.getWeatherBundle(41, -87), isNotNull);
  });
}
