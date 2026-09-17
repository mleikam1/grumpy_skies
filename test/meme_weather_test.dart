import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/meme_suggestions.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/cache_service.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final observedAt = DateTime.utc(2026, 9, 17, 2);

  WeatherBundle bundle({
    int? offset = -5 * 3600,
    int code = 500,
    String condition = 'Light rain',
    double temperatureC = 20,
  }) {
    return WeatherBundle(
      current: CurrentWeather(
        locationName: 'Test City, US',
        latitude: 41,
        longitude: -88,
        timezone: 'America/Chicago',
        timezoneOffset: offset,
        temperatureC: temperatureC,
        feelsLikeC: 19,
        windKph: 16.09344,
        humidity: 71,
        precipitationChance: 99,
        aqi: 22,
        sunrise: observedAt,
        sunset: observedAt,
        moonrise: observedAt,
        moonset: observedAt,
        uvIndex: 3,
        condition: condition,
        weatherId: code,
        lastUpdated: observedAt,
        sourceUpdatedAt: observedAt,
        // A recent download cannot make a stale observation fresh.
        fetchedAt: observedAt.add(const Duration(hours: 4)),
      ),
      hourly: const [],
      daily: const [],
    );
  }

  test('freezes units, actual observation age, timezone and city opt-in', () {
    final frozen = MemeWeather.freeze(
      bundle(),
      temperatureUnit: TemperatureUnit.celsius,
      windUnit: MemeWindUnit.kph,
      now: observedAt.add(const Duration(minutes: 15)),
    );
    expect(frozen['temperature'], 20);
    expect(frozen['feelsLike'], 19);
    expect(frozen['wind'], closeTo(16.09344, 0.00001));
    expect(frozen['day'], 'Wednesday');
    expect(frozen['timezone'], 'America/Chicago');
    expect(frozen['observedAt'], observedAt.toIso8601String());
    expect(frozen['stale'], false);
    expect(frozen, isNot(contains('latitude')));
    expect(frozen, isNot(contains('longitude')));
    expect(frozen, isNot(contains('city')));
    expect(MemeWeather.tokens(frozen)['temperature'], '20°C');
    expect(MemeWeather.tokens(frozen)['wind'], '16 km/h');
    expect(() => frozen['temperature'] = 100, throwsUnsupportedError);

    final stale = MemeWeather.freeze(
      bundle(),
      includeCity: true,
      now: observedAt.add(const Duration(hours: 4)),
    );
    expect(stale['temperature'], 68);
    expect(stale['wind'], closeTo(10, 0.00001));
    expect(stale['city'], 'Test City');
    expect(stale['stale'], true);
    expect(MemeWeather.statusLabel(stale), 'Stale cached weather');
    expect(frozen['stale'], false); // existing documents stay frozen
    expect(
        MemeWeather.statusLabel(frozen,
            now: observedAt.add(const Duration(days: 2))),
        'Stale cached weather');
    expect(frozen['observedAt'], observedAt.toIso8601String());
    expect(frozen['stale'], false); // age labels do not change frozen data
    expect(
      MemeWeather.statusLabel(MemeWeather.freeze(bundle(), isSample: true)),
      'Sample weather',
    );
  });

  test('missing timezone or token values do not invent facts', () {
    final unknownTimezone = MemeWeather.freeze(bundle(offset: null));
    expect(unknownTimezone, isNot(contains('day')));
    expect(MemeWeather.tokens(null), isEmpty);
    expect(MemeWeather.tokens({'source': 'custom'}), isEmpty);
    expect(
      MemeWeather.renderTokens('{city} {temperature} {missing}', null),
      '  ',
    );
    final sunny = MemeWeather.freeze(bundle(code: 800, condition: 'Clear'));
    expect(sunny['tags'], contains('clear_day'));
    expect(sunny['tags'], isNot(contains('rain')));
    expect(sunny['tags'], isNot(contains('pollen')));
    expect(sunny['tags'], isNot(contains('rainbow')));
    expect(sunny['tags'], isNot(contains('temperature_whiplash')));
  });

  test('cache-only adapter handles cache miss/corruption with no API traffic',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = await CacheService.create();
    final repository = _CountingWeatherRepository();
    final location = _location();
    final controller = WeatherLocationController(
      repository: repository,
      initialLocation: location,
    );
    addTearDown(controller.dispose);
    expect(MemeWeather.fromCache(cache, controller), isNull);
    await cache.saveWeatherBundle(
      lat: location.lat,
      lon: location.lon,
      bundle: bundle(),
    );
    for (var i = 0; i < 3; i++) {
      expect(MemeWeather.fromCache(cache, controller), isNotNull);
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((k) => k.startsWith('weather_cache_'))) {
      await prefs.setString(key, '{broken');
    }
    expect(MemeWeather.fromCache(cache, controller), isNull);
    expect(repository.calls, 0);
  });

  test(
      'source registry preserves exact case, lines, emoji and canonical persona',
      () {
    final registry = DisplayedRoastRegistry();
    addTearDown(registry.dispose);
    const exact = 'Sky, please.\nMy socks say NO ☔️';
    final source = DisplayedRoastSnapshot(
      id: 'displayed-42',
      text: exact,
      personaId: 'toddler',
      sourceKey: 'roasts',
      sourceLabel: 'Roasts',
      isSample: true,
    );
    registry.publish(source);
    expect(registry.choices.single.text, exact);
    expect(registry.choices.single.personaId, 'two_year_old');
    expect(registry.choices.single.chooserLabel, contains('Sample roast'));
    expect(registry.latestForecast, isNull);
    registry.clearSource('roasts');
    expect(registry.choices, isEmpty);
  });

  test('today suggestions require signals and never infer special phenomena',
      () async {
    final catalog = await MemeCatalog.load();
    expect(MemeSuggestions.chooseTemplate(catalog: catalog), isNull);
    final snapshot = MemeWeather.freeze(bundle());
    var recent = <String>[];
    for (var i = 0; i < 30; i++) {
      final selected = MemeSuggestions.chooseTemplate(
        catalog: catalog,
        weatherSnapshot: snapshot,
        recentIds: recent,
        random: Random(i),
      )!;
      expect(selected.tags.any((snapshot['tags'] as List).contains), true);
      expect(selected.autoSuggestRequiresVerifiedSignal, false);
      expect(selected.id, isNot('pollen_boss_battle'));
      expect(selected.id, isNot('rainbow_plot_twist'));
      expect(selected.id, isNot('temperature_whiplash'));
      recent = MemeSuggestions.remember(recent, selected.id);
    }
    expect(
      MemeSuggestions.chooseTemplate(
        catalog: catalog,
        weatherSnapshot: {
          'tags': ['cold']
        },
      ),
      isNull,
    );
  });

  test('persona suggestions preserve pairs and exhaust fresh jokes first',
      () async {
    final catalog = await MemeCatalog.load();
    final template = catalog.templateById('storm_boss_cat')!;
    final snapshot = MemeWeather.freeze(bundle());
    var recent = <String>[];
    final validPairs = [...template.captionPairs, ...catalog.personaCaptions];
    for (var i = 0; i < 7; i++) {
      final pair = MemeSuggestions.captionFor(
        catalog: catalog,
        template: template,
        personaId: 'toddler',
        weatherSnapshot: snapshot,
        recentIds: recent,
        random: Random(i),
      );
      if (i == 0) expect(pair.personaId, 'two_year_old');
      expect(pair.personaId, anyOf(isNull, 'two_year_old'));
      expect(recent, isNot(contains(pair.id)));
      final supplied = validPairs.singleWhere((source) => source.id == pair.id);
      expect(pair.top, supplied.top);
      expect(pair.bottom, supplied.bottom);
      recent = MemeSuggestions.remember(recent, pair.id);
    }
    final oldest = recent.first;
    final recycled = MemeSuggestions.captionFor(
      catalog: catalog,
      template: template,
      personaId: 'toddler',
      weatherSnapshot: snapshot,
      recentIds: recent,
    );
    expect(recycled.id, oldest);
  });

  test('persisted exhausted caption deck continues oldest-first after restart',
      () async {
    final catalog = await MemeCatalog.load();
    final template = catalog.templateById('storm_boss_cat')!;
    final backend = MemoryMemeBackend();
    var store = MemeStore(backend);
    final expected = <String>[];
    for (var i = 0; i < 7; i++) {
      final pair = MemeSuggestions.captionFor(
          catalog: catalog,
          template: template,
          personaId: 'karen',
          weatherSnapshot: {
            'tags': ['rain']
          },
          recentIds: await store.recentCaptionIds(),
          random: Random(i));
      expected.add(pair.id);
      await store.rememberCaption(pair.id);
      store = MemeStore(backend);
    }
    expect(expected.toSet().length, 7);
    expect(await store.recentCaptionIds(), expected);
    final next = MemeSuggestions.captionFor(
        catalog: catalog,
        template: template,
        personaId: 'karen',
        weatherSnapshot: {
          'tags': ['rain']
        },
        recentIds: await store.recentCaptionIds());
    expect(next.id, expected.first);
    expect(next.id, isNot(expected.last));
  });

  testWidgets('Share to Meme passes the exact displayed roast, never a reroll',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const repository = FakeWeatherRepository();
    final locations = WeatherLocationController(
      repository: repository,
      initialLocation: _location(),
    );
    final registry = DisplayedRoastRegistry();
    DisplayedRoastSnapshot? received;
    final router = GoRouter(
      initialLocation: '/forecast-test',
      routes: [
        GoRoute(
          path: '/forecast-test',
          builder: (_, __) => const ForecastScreen(),
        ),
        GoRoute(
          path: AppRoutes.memeGenerator,
          builder: (_, state) {
            received = state.extra! as DisplayedRoastSnapshot;
            return const Scaffold(body: Text('Meme destination'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(locations.dispose);
    addTearDown(registry.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: repository),
        ChangeNotifierProvider<WeatherLocationController>.value(
            value: locations),
        ChangeNotifierProvider<DisplayedRoastRegistry>.value(value: registry),
      ],
      child: MaterialApp.router(theme: DMTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final card =
        tester.widget<ForecastRoastCard>(find.byType(ForecastRoastCard));
    expect(registry.latestForecast!.text, card.roast.text);
    await tester.ensureVisible(find.text('Share to Meme'));
    await tester.tap(find.text('Share to Meme'));
    await tester.pumpAndSettle();
    expect(received!.id, card.roast.id);
    expect(received!.text, card.roast.text);
    expect(received!.personaId, card.roast.personaId);
    expect(received!.isSample, true);
    expect(find.text('Meme destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _CountingWeatherRepository extends FakeWeatherRepository {
  int calls = 0;

  @override
  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    calls++;
    return super.getSnapshot(
      latitude: latitude,
      longitude: longitude,
      forceRefresh: forceRefresh,
    );
  }
}

WeatherLocation _location() => WeatherLocation(
      name: 'Demo City',
      country: 'US',
      latitude: 41.8781,
      longitude: -87.6298,
      source: WeatherLocationSource.manual,
      updatedAt: DateTime(2026, 9, 17),
    );
