import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app/daymaker_app.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_repository.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/roasts_screen.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/pack_roast_repository.dart';
import 'package:grumpy_skies/repositories/roast_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
          ({
            SettingsController settings,
            _WeatherRepository weather,
            DisplayedRoastRegistry registry
          })>
      pump(WidgetTester tester,
          {WeatherBundle? initialWeather,
          bool fixture = true,
          bool selectedLocation = true,
          ValueChanged<DisplayedRoastSnapshot>? onMeme,
          Size size = const Size(390, 930),
          double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController()..setSelectedPersonaId('grandpa');
    final weather =
        _WeatherRepository(initialWeather ?? ApprovedFixture.weather);
    final locations = WeatherLocationController(
        repository: weather,
        initialLocation: selectedLocation ? ApprovedFixture.location : null,
        clock: () => ApprovedFixture.now);
    final registry = DisplayedRoastRegistry();
    final RoastRepository repository = fixture
        ? const ApprovedRoastRepository()
        : PackRoastRepository(
            packs: _Packs(), clock: () => ApprovedFixture.now);
    final router = GoRouter(initialLocation: AppRoutes.roasts, routes: [
      GoRoute(
          path: AppRoutes.roasts,
          builder: (_, __) => RoastsScreen(
              initialWeather: initialWeather,
              isSample: fixture,
              clock: () => ApprovedFixture.now)),
      GoRoute(
          path: AppRoutes.memeGenerator,
          builder: (_, state) {
            onMeme?.call(state.extra! as DisplayedRoastSnapshot);
            return const Scaffold(body: Text('Meme destination'));
          }),
      GoRoute(
          path: AppRoutes.forecast,
          builder: (_, __) => const Scaffold(body: Text('Today destination'))),
    ]);
    addTearDown(settings.dispose);
    addTearDown(locations.dispose);
    addTearDown(registry.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: locations),
          ChangeNotifierProvider.value(value: registry),
          Provider<RoastRepository>.value(value: repository),
          Provider<WeatherRepository>.value(value: weather),
        ],
        child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: DaymakerApp(routerConfig: router))));
    await tester.pumpAndSettle();
    return (settings: settings, weather: weather, registry: registry);
  }

  testWidgets(
      'approved composition selects Grandpa and shows all five selectors',
      (tester) async {
    await pump(tester, initialWeather: ApprovedFixture.weather);
    expect(tester.takeException(), isNull);
    expect(find.text('Roasts'), findsOneWidget);
    expect(find.text('Same weather.\nDifferent takes.'), findsOneWidget);
    expect(find.text('Grandpa.'), findsOneWidget);
    expect(find.text('WEATHER WISEGUY'), findsOneWidget);
    expect(find.text('“${ApprovedFixture.grandpaQuote}”'), findsOneWidget);
    for (final name in [
      'Karen',
      'Frat Bro',
      'Politician',
      'Grandpa',
      '2-Year-Old'
    ]) {
      expect(find.text(name), findsWidgets);
    }
    expect(find.text('Another roast'), findsOneWidget);
    expect(find.text('More from the crew'), findsOneWidget);
  });

  testWidgets(
      'persona selection persists and Copy uses exactly the displayed quote',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final state = await pump(tester, initialWeather: ApprovedFixture.weather);
    await tester.tap(find.byKey(const ValueKey('persona-card-frat_bro')));
    await tester.pumpAndSettle();
    expect(state.settings.selectedPersonaId, 'frat_bro');
    final card =
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard));
    await tester.ensureVisible(find.text('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();
    expect(copied, card.roast.text);
    expect(find.text('Roast copied.'), findsOneWidget);
  });

  testWidgets('Make a meme carries the frozen displayed quote and weather',
      (tester) async {
    DisplayedRoastSnapshot? received;
    await pump(tester,
        initialWeather: ApprovedFixture.weather,
        onMeme: (value) => received = value);
    final card =
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard));
    await tester.ensureVisible(find.text('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a meme'));
    await tester.pumpAndSettle();
    expect(received?.text, card.roast.text);
    expect(received?.id, card.roast.id);
    expect(received?.personaId, 'grandpa');
    expect(received?.weatherSnapshot?['temperature'], 72);
    expect(find.text('Meme destination'), findsOneWidget);
  });

  testWidgets(
      'production deep link fetches once; mode changes and Another do not refetch',
      (tester) async {
    final state = await pump(tester, fixture: false);
    expect(state.weather.calls, 1);
    final first =
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard)).roast;
    state.settings.setAppearance(AppAppearance.dark);
    await tester.pumpAndSettle();
    expect(
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard)).roast,
        same(first));
    expect(state.weather.calls, 1);
    await tester.ensureVisible(find.text('Another roast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another roast'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard))
            .roast
            .text,
        isNot(first.text));
    expect(state.weather.calls, 1);
    expect(state.registry.choices.first.isSample, false);
  });

  testWidgets(
      'missing location has no fake weather; active warning suppresses jokes',
      (tester) async {
    final empty = await pump(tester, fixture: false, selectedLocation: false);
    expect(empty.weather.calls, 0);
    expect(find.text('Choose your forecast location'), findsOneWidget);
    expect(find.byType(FeaturedRoastCard), findsNothing);
    final alertWeather = WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'alerts': [
        WeatherAlert(
                senderName: 'NWS',
                event: 'Tornado warning',
                description: 'Take shelter',
                end: ApprovedFixture.now.add(const Duration(hours: 1)))
            .toJson(),
      ]
    });
    await pump(tester, fixture: false, initialWeather: alertWeather);
    expect(find.text('Weather alerts take priority'), findsOneWidget);
    expect(find.byType(FeaturedRoastCard), findsNothing);
    expect(find.text('Another roast'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets(
      'Roasts adapts at narrow, tablet and desktop widths in both modes',
      (tester) async {
    for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1440.0]) {
      final state = await pump(tester,
          initialWeather: ApprovedFixture.weather,
          size: Size(width, 930),
          textScale: width == 320 ? 2 : 1);
      expect(tester.takeException(), isNull, reason: 'Light $width');
      state.settings.setAppearance(AppAppearance.dark);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Dark $width');
    }
  });

  test(
      'pack requires real context, avoids repeat, and records only displayed history',
      () async {
    final repository = PackRoastRepository(packs: _Packs());
    expect(
        () => repository.getDailyRoast(
            personaId: 'grandpa', weatherSnapshotId: 'none'),
        throwsStateError);
    repository.setWeather(ApprovedFixture.weather, TemperatureUnit.celsius);
    final first = await repository.getDailyRoast(
        personaId: 'grandpa', weatherSnapshotId: 'actual');
    expect(first.text, contains('22°C'));
    expect(await repository.getRoastHistory(), isEmpty);
    repository.recordDisplayed(first);
    final next = await repository.nextRoast(
        personaId: 'grandpa', weatherSnapshotId: 'actual');
    expect(next.text, isNot(first.text));
    expect(await repository.getRoastHistory(), [first]);
  });
}

class _WeatherRepository extends WeatherRepository {
  _WeatherRepository(this.weather);
  final WeatherBundle weather;
  int calls = 0;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    calls++;
    return weather;
  }

  @override
  Future<WeatherSnapshot> getSnapshot(
          {required double latitude,
          required double longitude,
          bool forceRefresh = false}) async =>
      weather.snapshot!;
  @override
  Future<List<RadarAlert>> getRadarAlerts(
          {required double latitude, required double longitude}) async =>
      [];
}

class _Packs extends RoastPackRepository {
  @override
  Future<RoastPack> loadPack(
          {RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
          int appBuildNumber = 1}) async =>
      RoastPack(
          schemaVersion: 1,
          packVersion: 'test',
          generatedAt: ApprovedFixture.now,
          personas: ApprovedFixture.personaOrder,
          roasts: [
            for (final id in ApprovedFixture.personaOrder)
              for (var i = 0; i < 2; i++)
                RoastLine(
                    id: '$id-$i',
                    persona: id,
                    type: RoastType.today,
                    tags: const [WeatherRoastTag.fallback],
                    dayparts: const [Daypart.any],
                    level: RoastLevel.mild,
                    weight: 1,
                    text: 'Local line $i at {temp}{temp_unit}.')
          ]);
}
