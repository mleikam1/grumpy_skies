import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app.dart';
import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/fun/fun_zone_screen.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/features/roasts/advanced_roast_reveal_screen.dart';
import 'package:grumpy_skies/features/roasts/roasts_screen.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/features/splash/splash_screen.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/roast_repository.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/persona_roast_service.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

class DayMakerTestViewport {
  const DayMakerTestViewport({
    required this.label,
    required this.size,
  });

  final String label;
  final Size size;

  @override
  String toString() => label;
}

const dayMakerPhoneViewport = DayMakerTestViewport(
  label: '390x844 phone',
  size: Size(390, 844),
);

const dayMakerTabletViewport = DayMakerTestViewport(
  label: '768x1024 tablet',
  size: Size(768, 1024),
);

const dayMakerDesktopViewport = DayMakerTestViewport(
  label: '1440x900 desktop',
  size: Size(1440, 900),
);

const dayMakerTestViewports = <DayMakerTestViewport>[
  dayMakerPhoneViewport,
  dayMakerTabletViewport,
  dayMakerDesktopViewport,
];

extension DayMakerWidgetTester on WidgetTester {
  void setDayMakerSurfaceSize(Size size) {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpDayMakerApp({
    DayMakerTestViewport viewport = dayMakerPhoneViewport,
  }) async {
    setDayMakerSurfaceSize(viewport.size);

    await pumpWidget(
      await buildDayMakerTestProviders(
        child: const GrumpySkiesApp(),
      ),
    );
    await pumpAndSettle();
  }

  Future<void> pumpDayMakerRoute({
    required String initialLocation,
    DayMakerTestViewport viewport = dayMakerPhoneViewport,
    double textScale = 1,
  }) async {
    setDayMakerSurfaceSize(viewport.size);

    final router = buildDayMakerTestRouter(initialLocation: initialLocation);

    final app = await buildDayMakerTestProviders(
      child: MaterialApp.router(
        theme: DMTheme.light,
        routerConfig: router,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
      ),
    );
    if (initialLocation == AppRoutes.memeGenerator) {
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      const lostData = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.image_picker_android.ImagePickerApi.retrieveLostResults',
        StandardMessageCodec(),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(picker, (_) async => null);
      messenger.setMockDecodedMessageHandler<Object?>(
          lostData, (_) async => <Object?>[null]);
      addTearDown(() {
        messenger.setMockMethodCallHandler(picker, null);
        messenger.setMockDecodedMessageHandler<Object?>(lostData, null);
      });
      // Bundled fonts and image decoding use real async engine work. Wait for
      // the catalog without advancing an indefinite loading spinner in fake time.
      await runAsync(() async {
        await loadMemeFonts();
        await pumpWidget(app);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var attempt = 0; attempt < 40; attempt++) {
        await pump();
        await runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await pump();
        if (find.byType(MemeLibrary).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byType(MemeLibrary), findsOneWidget);
    } else {
      await pumpWidget(app);
    }
    await pumpAndSettle();
  }
}

Future<Widget> buildDayMakerTestProviders({
  required Widget child,
  WeatherLocation? initialWeatherLocation,
}) async {
  final settingsRepository = InMemorySettingsRepository();
  final settingsController = SettingsController(repository: settingsRepository);
  await settingsController.loadSettings();
  const weatherRepository = FakeWeatherRepository();
  final locationController = WeatherLocationController(
    repository: weatherRepository,
    initialLocation: initialWeatherLocation ?? buildTestWeatherLocation(),
  );

  return MultiProvider(
    providers: [
      Provider<WeatherRepository>.value(value: weatherRepository),
      Provider<RoastRepository>.value(value: const FakeRoastRepository()),
      Provider<SettingsRepository>.value(value: settingsRepository),
      Provider<PersonaRoastService>.value(value: PersonaRoastService()),
      ChangeNotifierProvider<WeatherLocationController>.value(
        value: locationController,
      ),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController,
      ),
    ],
    child: child,
  );
}

WeatherLocation buildTestWeatherLocation() {
  return WeatherLocation(
    name: 'Demo City',
    country: 'US',
    latitude: 41.8781,
    longitude: -87.6298,
    source: WeatherLocationSource.manual,
    updatedAt: DateTime(2026, 6, 14, 9),
  );
}

GoRouter buildDayMakerTestRouter({required String initialLocation}) {
  final memeStore = MemeStore(MemoryMemeBackend());
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DaymakerShell(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.forecast,
            builder: (context, state) => const ForecastScreen(),
          ),
          GoRoute(
            path: AppRoutes.roasts,
            builder: (context, state) => const RoastsScreen(),
            routes: [
              GoRoute(
                path: 'reveal',
                builder: (context, state) => const AdvancedRoastRevealScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.radar,
            builder: (context, state) => const RadarScreen(),
          ),
          GoRoute(
            path: AppRoutes.fun,
            builder: (context, state) => const FunZoneScreen(),
            routes: [
              GoRoute(
                path: 'meme',
                builder: (context, state) =>
                    MemeGeneratorScreen(store: memeStore),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void expectNoFlutterExceptions(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
