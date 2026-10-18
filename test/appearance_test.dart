import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/app/daymaker_app.dart';
import 'package:grumpy_skies/data/daymaker_sample_data.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/shared_preferences_settings_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';
import 'package:grumpy_skies/features/splash/splash_screen.dart';
import 'helpers/daymaker_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new installs default to Light; unrelated preferences survive saves',
      () async {
    SharedPreferences.setMockInitialValues({'unrelated.savedDraft': 'keep me'});
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSettingsRepository(prefs);
    final initial = await repository.loadSettings();
    expect(initial.appearance, AppAppearance.light);
    await repository
        .saveSettings(initial.copyWith(appearance: AppAppearance.dark));
    expect((await repository.loadSettings()).appearance, AppAppearance.dark);
    expect(prefs.getString('unrelated.savedDraft'), 'keep me');
  });

  for (final legacy in <Map<String, Object>>[
    {'settings.themeMode': 'ThemeMode.dark'},
    {'themeMode': 'dark'},
    {'theme_mode': 'DARK'},
    {'appearance': 'dark'},
    {'settings.darkMode': true},
    {'darkMode': true},
    {'isDarkMode': true},
  ]) {
    test('migrates explicit preference $legacy without clearing old keys',
        () async {
      SharedPreferences.setMockInitialValues({
        ...legacy,
        'settings.temperatureUnit': 'celsius',
        'settings.selectedPersonaId': 'grandpa',
        'settings.notificationsEnabled': false,
        'settings.xp': 1234,
        'settings.level': 9,
        'settings.streakDays': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesSettingsRepository(prefs);
      final settings = await repository.loadSettings();
      expect(settings.appearance, AppAppearance.dark);
      expect(settings.temperatureUnit, TemperatureUnit.celsius);
      expect(prefs.containsKey('settings.selectedPersonaId'), isFalse);
      expect(settings.notificationsEnabled, false);
      expect(settings.xp, 1234);
      expect(settings.level, 9);
      expect(settings.streakDays, 7);
      await repository.saveSettings(settings);
      for (final entry in legacy.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
    });
  }

  test('canonical System preference wins over old dark flag', () async {
    SharedPreferences.setMockInitialValues({
      'settings.appearance': 'system',
      'darkMode': true,
    });
    final repository = SharedPreferencesSettingsRepository(
        await SharedPreferences.getInstance());
    expect((await repository.loadSettings()).appearance, AppAppearance.system);
  });

  test('malformed appearance falls back safely without deleting its source',
      () async {
    SharedPreferences.setMockInitialValues({'settings.appearance': 17});
    final prefs = await SharedPreferences.getInstance();
    expect(
        (await SharedPreferencesSettingsRepository(prefs).loadSettings())
            .appearance,
        AppAppearance.light);
    expect(prefs.get('settings.appearance'), 17);
  });

  test(
      'rapid changes serialize writes and preserve the latest complete settings',
      () async {
    final repository = _DelayedSettingsRepository();
    final controller = SettingsController(repository: repository);
    await controller.loadSettings();
    controller.setAppearance(AppAppearance.dark);
    controller.setTemperatureUnit(TemperatureUnit.celsius);
    controller.setAppearance(AppAppearance.system);
    expect(repository.writes, hasLength(1));
    expect(controller.appearance, AppAppearance.system);
    repository.completeNext();
    await Future<void>.delayed(Duration.zero);
    expect(repository.writes, hasLength(2));
    expect(repository.maxActiveWrites, 1);
    repository.completeNext();
    await controller.waitForPendingSave();
    expect(repository.saved.appearance, AppAppearance.system);
    expect(repository.saved.temperatureUnit, TemperatureUnit.celsius);
    expect(controller.isSaving, false);
    controller.dispose();
  });

  test('failed save is visible and retry persists the current preference',
      () async {
    final repository = _DelayedSettingsRepository();
    final controller = SettingsController(repository: repository);
    await controller.loadSettings();
    controller.setAppearance(AppAppearance.dark);
    repository.completeNext(error: StateError('disk unavailable'));
    await controller.waitForPendingSave();
    expect(controller.lastError, isA<StateError>());
    expect(controller.appearance, AppAppearance.dark);
    controller.retrySave();
    repository.completeNext();
    await controller.waitForPendingSave();
    expect(controller.lastError, isNull);
    expect(repository.saved.appearance, AppAppearance.dark);
    controller.dispose();
  });

  test('finishing a save after disposal does not notify disposed listeners',
      () async {
    final repository = _DelayedSettingsRepository();
    final controller = SettingsController(repository: repository);
    controller.setAppearance(AppAppearance.dark);
    controller.dispose();
    repository.completeNext();
    await controller.waitForPendingSave();
  });

  testWidgets('actual Appearance selector updates and saves all three choices',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(
        repository: SharedPreferencesSettingsRepository(prefs));
    await controller.loadSettings();
    final app = await buildDayMakerTestProviders(
        child: ChangeNotifierProvider.value(
      value: controller,
      child:
          MaterialApp(theme: DMTheme.lightTheme, home: const SettingsScreen()),
    ));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    for (final appearance in [
      AppAppearance.dark,
      AppAppearance.system,
      AppAppearance.light
    ]) {
      await tester.ensureVisible(find.text(appearance.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(appearance.label));
      await tester.pumpAndSettle();
      await controller.waitForPendingSave();
      expect(controller.appearance, appearance);
      expect(prefs.getString('settings.appearance'), appearance.name);
    }
    controller.dispose();
  });

  testWidgets(
      'derived screens fit both appearances at narrow and large-text sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final theme in [DMTheme.lightTheme, DMTheme.darkTheme]) {
        for (final screen in [
          const SettingsScreen(),
          const AboutScreen(),
          const SplashScreen()
        ]) {
          final app = await buildDayMakerTestProviders(
              child: MaterialApp(
            key: UniqueKey(),
            theme: theme,
            home: screen,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
              child: child!,
            ),
          ));
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$screen at $width / ${theme.brightness}');
        }
      }
    }
  });

  testWidgets('reduced motion disables theme interpolation', (tester) async {
    final controller = SettingsController();
    final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const _StateProbe())]);
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: DaymakerApp(routerConfig: router))));
    expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero);
  });

  test('theme geometry and typography match while colors differ', () {
    expect(DMTheme.lightTheme.brightness, Brightness.light);
    expect(DMTheme.darkTheme.brightness, Brightness.dark);
    expect(
        (DMTheme.lightTheme.cardTheme.shape as RoundedRectangleBorder)
            .borderRadius,
        (DMTheme.darkTheme.cardTheme.shape as RoundedRectangleBorder)
            .borderRadius);
    expect(DMTheme.lightTheme.textTheme.displayLarge?.fontSize,
        DMTheme.darkTheme.textTheme.displayLarge?.fontSize);
    expect(DMTheme.lightTheme.textTheme.bodyMedium?.fontFamily,
        DMTheme.darkTheme.textTheme.bodyMedium?.fontFamily);
    expect(DMTheme.lightTheme.scaffoldBackgroundColor,
        isNot(DMTheme.darkTheme.scaffoldBackgroundColor));
    for (final colors in [DMSemanticColors.light, DMSemanticColors.dark]) {
      for (final foreground in [
        colors.textPrimary,
        colors.textSecondary,
        colors.textMuted
      ]) {
        expect(
            _contrast(foreground, colors.surface), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets(
      'saved Dark renders on the first app frame; System alone follows brightness',
      (tester) async {
    SharedPreferences.setMockInitialValues({'settings.appearance': 'dark'});
    final controller = SettingsController(
        repository: SharedPreferencesSettingsRepository(
            await SharedPreferences.getInstance()));
    await controller.loadSettings();
    final router = GoRouter(initialLocation: '/settings', routes: [
      GoRoute(path: '/settings', builder: (_, __) => const _StateProbe()),
    ]);
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller, child: DaymakerApp(routerConfig: router)));
    expect(Theme.of(tester.element(find.byType(_StateProbe))).brightness,
        Brightness.dark);
    controller.setAppearance(AppAppearance.system);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(_StateProbe))).brightness,
        Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(_StateProbe))).brightness,
        Brightness.dark);
    controller.setAppearance(AppAppearance.light);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(_StateProbe))).brightness,
        Brightness.light);
  });

  testWidgets(
      'appearance changes retain route, mounted state, scroll and an editable draft',
      (tester) async {
    final controller = SettingsController();
    final key = GlobalKey<_StateProbeState>();
    final router = GoRouter(initialLocation: '/fun/meme', routes: [
      GoRoute(path: '/fun/meme', builder: (_, __) => _StateProbe(key: key)),
    ]);
    addTearDown(router.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller, child: DaymakerApp(routerConfig: router)));
    await tester.enterText(find.byType(TextField), 'Exact quote, unchanged.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    key.currentState!.scroll.jumpTo(300);
    await tester.pump();
    final oldState = key.currentState;
    controller.setAppearance(AppAppearance.dark);
    await tester.pumpAndSettle();
    expect(key.currentState, same(oldState));
    expect(key.currentState!.scroll.offset, 300);
    expect(key.currentState!.draft.text, 'Exact quote, unchanged.');
    expect(router.routeInformationProvider.value.uri.path, '/fun/meme');
  });
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key});
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  final scroll = ScrollController();
  final draft = TextEditingController();
  @override
  void dispose() {
    scroll.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView(controller: scroll, children: [
        TextField(controller: draft),
        const SizedBox(height: 2000),
      ]));
}

class _DelayedSettingsRepository extends SettingsRepository {
  UserSettings saved = DayMakerSampleData.userSettings;
  final writes = <UserSettings>[];
  final pending = <Completer<void>>[];
  int activeWrites = 0;
  int maxActiveWrites = 0;
  @override
  Future<UserSettings> loadSettings() async => saved;
  @override
  Future<void> saveSettings(UserSettings settings) async {
    writes.add(settings);
    activeWrites++;
    if (activeWrites > maxActiveWrites) maxActiveWrites = activeWrites;
    final gate = Completer<void>();
    pending.add(gate);
    try {
      await gate.future;
      saved = settings;
    } finally {
      activeWrites--;
    }
  }

  void completeNext({Object? error}) {
    final gate = pending.removeAt(0);
    if (error == null) {
      gate.complete();
    } else {
      gate.completeError(error);
    }
  }
}
