import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/roasts/advanced_roast_reveal_screen.dart';
import 'package:grumpy_skies/features/roasts/widgets/advanced_roast_reveal_card.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  DisplayedRoastSnapshot source(
          {String text = 'Exact displayed quote — no reroll.',
          String id = 'displayed-one'}) =>
      DisplayedRoastSnapshot(
        id: id,
        text: text,
        personaId: 'grandpa',
        sourceKey: 'roasts',
        sourceLabel: 'Roasts',
        isSample: false,
        weatherSnapshot: const {
          'temperature': 72,
          'city': 'Frozen City',
          'condition': 'Partly cloudy'
        },
        capturedAt: ApprovedFixture.now,
      );

  Future<
          ({
            DisplayedRoastRegistry registry,
            WeatherLocationController location,
            ValueNotifier<Brightness> brightness
          })>
      pump(WidgetTester tester,
          {DisplayedRoastSnapshot? initialRoast,
          bool seedRegistry = true,
          bool reducedMotion = false,
          double width = 390,
          double textScale = 1,
          ValueChanged<DisplayedRoastSnapshot>? onMeme}) async {
    tester.view.physicalSize = Size(width, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final registry = DisplayedRoastRegistry();
    if (seedRegistry) registry.publish(source());
    final location = WeatherLocationController(
        repository: const FakeWeatherRepository(),
        initialLocation: ApprovedFixture.location,
        clock: () => ApprovedFixture.now);
    final brightness = ValueNotifier(Brightness.light);
    final router = GoRouter(initialLocation: AppRoutes.roastReveal, routes: [
      GoRoute(
          path: AppRoutes.roastReveal,
          builder: (_, __) =>
              AdvancedRoastRevealScreen(initialRoast: initialRoast)),
      GoRoute(
          path: AppRoutes.roasts,
          builder: (_, __) => const Scaffold(body: Text('Roasts destination'))),
      GoRoute(
          path: AppRoutes.forecast,
          builder: (_, __) =>
              const Scaffold(body: Text('Weather destination'))),
      GoRoute(
          path: AppRoutes.memeGenerator,
          builder: (_, state) {
            onMeme?.call(state.extra as DisplayedRoastSnapshot);
            return const Scaffold(body: Text('Meme destination'));
          }),
    ]);
    addTearDown(registry.dispose);
    addTearDown(location.dispose);
    addTearDown(brightness.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: registry),
          ChangeNotifierProvider.value(value: location),
        ],
        child: ValueListenableBuilder(
            valueListenable: brightness,
            builder: (_, value, __) => MaterialApp.router(
                  theme: value == Brightness.light
                      ? DMTheme.lightTheme
                      : DMTheme.darkTheme,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          disableAnimations: reducedMotion,
                          textScaler: TextScaler.linear(textScale)),
                      child: child!),
                ))));
    await tester.pumpAndSettle();
    return (registry: registry, location: location, brightness: brightness);
  }

  testWidgets('registry source is hidden until reveal with no invented rewards',
      (tester) async {
    await pump(tester);
    expect(find.text('Roast reveal'), findsOneWidget);
    expect(find.text('Frozen City · Roasts'), findsOneWidget);
    expect(find.text('Exact displayed quote — no reroll.'), findsNothing);
    expect(find.text('Clear the clouds to reveal your roast'), findsOneWidget);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.textContaining('Level 3'), findsNothing);
    expect(find.text('Achievements'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tap toggles reveal, drag reveals, and zero XP is never displayed',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Clear the clouds to reveal your roast'));
    await tester.pumpAndSettle();
    expect(find.text('Exact displayed quote — no reroll.'), findsOneWidget);
    expect(find.text('+0 XP'), findsNothing);
    await tester.tap(find.text('Hide roast'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(AdvancedRoastRevealCard), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Exact displayed quote — no reroll.'), findsOneWidget);
  });

  testWidgets('keyboard reveal works and reduced motion disables the switcher',
      (tester) async {
    await pump(tester, reducedMotion: true);
    final button = find.widgetWithText(OutlinedButton, 'Reveal roast');
    final focus = Focus.of(tester
        .element(find.descendant(of: button, matching: find.byType(Text))));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Exact displayed quote — no reroll.'), findsOneWidget);
    final switcher = tester.widget<AnimatedSwitcher>(find.descendant(
        of: find.byType(AdvancedRoastRevealCard),
        matching: find.byType(AnimatedSwitcher)));
    expect(switcher.duration, Duration.zero);
  });

  testWidgets('entry snapshot stays frozen when registry and theme change',
      (tester) async {
    final state = await pump(tester);
    state.registry.publish(source(text: 'New registry quote', id: 'new-id'));
    state.brightness.value = Brightness.dark;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal roast'));
    await tester.pumpAndSettle();
    expect(find.text('Exact displayed quote — no reroll.'), findsOneWidget);
    expect(find.text('New registry quote'), findsNothing);
  });

  testWidgets(
      'route source overrides registry and exact Copy/meme handoff is preserved',
      (tester) async {
    String? copied;
    DisplayedRoastSnapshot? received;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final passed = source(
        text: 'Original quoted caption; punctuation intact!',
        id: 'route-extra');
    await pump(tester,
        initialRoast: passed, onMeme: (value) => received = value);
    await tester.tap(find.text('Reveal roast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();
    expect(copied, passed.text);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a meme'));
    await tester.pumpAndSettle();
    expect(received, same(passed));
    expect(received?.weatherSnapshot?['city'], 'Frozen City');
  });

  testWidgets(
      'empty entry directs to Roasts and arriving warnings suppress an open reveal',
      (tester) async {
    await pump(tester, seedRegistry: false);
    expect(find.text('Choose a roast to reveal'), findsOneWidget);
    expect(find.byType(AdvancedRoastRevealCard), findsNothing);
    await tester.tap(find.text('Open Roasts'));
    await tester.pumpAndSettle();
    expect(find.text('Roasts destination'), findsOneWidget);
    final state = await pump(tester);
    await tester.tap(find.text('Reveal roast'));
    await tester.pumpAndSettle();
    state.location.updateWeatherSafety(
        WeatherBundle.fromJson({
          ...ApprovedFixture.weather.toJson(),
          'alerts': [
            WeatherAlert(
                    senderName: 'NWS',
                    event: 'Tornado warning',
                    description: 'Take shelter',
                    end: ApprovedFixture.now.add(const Duration(hours: 1)))
                .toJson(),
          ]
        }),
        ApprovedFixture.location);
    await tester.pumpAndSettle();
    expect(find.text('Weather alerts take priority'), findsOneWidget);
    expect(find.byType(AdvancedRoastRevealCard), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets(
      'revealed content fits narrow, large text and wide views in both modes',
      (tester) async {
    for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1440.0]) {
      final state =
          await pump(tester, width: width, textScale: width == 320 ? 2 : 1);
      await tester.ensureVisible(find.text('Reveal roast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reveal roast'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Light $width');
      state.brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Dark $width');
    }
  });
}
