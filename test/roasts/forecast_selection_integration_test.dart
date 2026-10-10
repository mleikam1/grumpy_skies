import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/roasts/controllers/local_roast_controller.dart';
import 'package:grumpy_skies/features/roasts/services/local_roast_engine.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

class _Weather extends FakeWeatherRepository {
  WeatherBundle bundle = ApprovedFixture.weather;
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'Today: 100 local changes, exact share, persona rebuild and hidden alert exposure',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final weather = _Weather();
    final location = WeatherLocationController(
        repository: weather,
        initialLocation: ApprovedFixture.location,
        clock: () => ApprovedFixture.now);
    final settings = SettingsController();
    await settings.loadSettings();
    final local =
        LocalRoastController(initialPack: LocalRoastEngine.fallbackPack);
    await local.initialize(persist: false);
    final registry = DisplayedRoastRegistry();
    addTearDown(location.dispose);
    addTearDown(settings.dispose);
    addTearDown(local.dispose);
    addTearDown(registry.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: weather),
          ChangeNotifierProvider.value(value: location),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: local),
          ChangeNotifierProvider.value(value: registry),
        ],
        child: MaterialApp(
            theme: DMTheme.light,
            home: ForecastScreen(clock: () => ApprovedFixture.now))));
    await tester.pumpAndSettle();
    expect(weather.requests, 1);
    NetworkCounters.instance.reset();
    for (var i = 0; i < 100; i++) {
      final priorExposureCount = local.engine.exposureCount;
      await Scrollable.ensureVisible(
          tester.element(find.bySemanticsLabel('Another')),
          alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Another'));
      await tester.pumpAndSettle();
      expect(local.engine.exposureCount, greaterThan(priorExposureCount),
          reason: 'Another action $i actually displayed a new selection.');
      if (i % 20 == 0) {
        settings.setSelectedPersonaId(i % 40 == 0 ? 'grandpa' : 'karen');
        settings.setAppearance(
            i % 40 == 0 ? AppAppearance.dark : AppAppearance.light);
        await tester.pumpAndSettle();
      }
    }
    settings.setSelectedPersonaId('two_year_old');
    await tester.pumpAndSettle();
    final shown =
        tester.widget<ForecastRoastCard>(find.byType(ForecastRoastCard)).roast;
    expect(registry.latestForecast!.personaId, 'two_year_old');
    expect(registry.latestForecast!.selection, same(shown.selection));
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
    await Scrollable.ensureVisible(
        tester.element(find.bySemanticsLabel('Share')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();
    expect(copied, shown.text);
    expect(weather.requests, 1);
    expect(NetworkCounters.instance.snapshot, isEmpty);
    final beforeAlert = local.engine.exposureCount;
    weather.bundle = WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'alerts': [
        {
          'id': 'fixture-warning',
          'event': 'Fixture warning',
          'senderName': 'Test agency',
          'description': 'Official fixture text',
          'start': ApprovedFixture.now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'end': ApprovedFixture.now
              .add(const Duration(hours: 1))
              .toIso8601String()
        }
      ]
    });
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.byType(ForecastRoastCard), findsNothing);
    expect(local.engine.exposureCount, beforeAlert,
        reason: 'Hidden safety state is not an exposed roast.');
    expect(registry.latestForecast, isNull);
    expect(weather.requests, 2,
        reason: 'Explicit refresh is separately counted.');
  });
}
