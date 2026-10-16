import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/models/daymaker_models.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_surface.dart';

const _longText =
    'The clouds have scheduled another meeting about whether the sunshine '
    'should arrive before lunch, and I am still waiting for a complete answer '
    'from the committee responsible for this exceptionally indecisive forecast.';
const _source = 'Saved forecast for a very long metropolitan location name';

Roast _roast(String persona, RoastMood mood, {String text = _longText}) =>
    Roast(
      id: 'compact-sky-$persona-$text',
      personaId: persona,
      weatherSnapshotId: 'unchanged-weather',
      text: text,
      category: 'today',
      mood: mood,
      createdAt: DateTime.utc(2026, 10, 10),
      xpReward: 0,
    );

Widget _app({
  required Widget child,
  bool dark = false,
  double scale = 1,
  ThemeMode? mode,
}) =>
    MaterialApp(
      theme: DMTheme.light,
      darkTheme: DMTheme.dark,
      themeMode: mode ?? (dark ? ThemeMode.dark : ThemeMode.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final entry = manifest
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['family'] == 'DaymakerSans');
    final loader = FontLoader('DaymakerSans');
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  });

  const moods = {
    'karen': RoastMood.annoyed,
    'frat_bro': RoastMood.hyped,
    'grandpa': RoastMood.cozy,
    'politician': RoastMood.confident,
    'two_year_old': RoastMood.happy,
  };

  for (final dark in [false, true]) {
    for (final size in [(390.0, 1.0), (320.0, 2.0), (768.0, 2.0)]) {
      testWidgets(
          'compact cards keep artwork, text and targets '
          'dark=$dark width=${size.$1} scale=${size.$2}', (tester) async {
        tester.view.physicalSize = Size(size.$1, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final entry in moods.entries) {
          final persona = RoastPersonas.byId(entry.key).toDayMakerPersona();
          await tester.pumpWidget(_app(
            dark: dark,
            scale: size.$2,
            child: ForecastRoastCard(
              persona: persona,
              roast: _roast(entry.key, entry.value),
              sourceLabel: _source,
              onNewRoast: () {},
              onShare: () {},
            ),
          ));
          await tester.pumpAndSettle();
          final colors = dark ? DMRoastColors.dark : DMRoastColors.light;
          final surface = tester.widget<DmRoastSurface>(
              find.byKey(const ValueKey('today-persona-card')));
          expect(surface.colors, colors);
          expect(surface.padding, const EdgeInsets.fromLTRB(8, 14, 14, 12));
          expect(surface.borderRadius, BorderRadius.circular(22));
          expect(find.text("${persona.name}'s take"), findsOneWidget);
          expect(find.text('“$_longText”'), findsOneWidget);
          expect(tester.widget<Text>(find.text(_source)).style!.color,
              colors.textSecondary);
          expect(tester.widget<Text>(find.text('“$_longText”')).style!.color,
              colors.textPrimary);
          final portrait =
              tester.widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait));
          expect(portrait.personaId, entry.key);
          expect(portrait.mood, entry.value);
          expect(portrait.height, size.$2 == 1 ? 175 : 126);
          final image = tester.widget<Image>(find.descendant(
              of: find.byType(DmPersonaPortrait),
              matching: find.byType(Image)));
          expect((image.image as AssetImage).assetName,
              DmPersonaPortrait.pathFor(entry.key, mood: entry.value));
          expect(image.color, isNull);
          expect(find.byType(ColorFiltered), findsNothing);
          final card = tester.getRect(find.byType(ForecastRoastCard));
          for (final element in find
              .descendant(
                  of: find.byType(ForecastRoastCard),
                  matching: find.byType(Text))
              .evaluate()) {
            final paragraph = element.findRenderObject()! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(paragraph.size.width, lessThanOrEqualTo(card.width));
          }
          for (final label in ['Another', 'Share']) {
            final button = find.ancestor(
                of: find.text(label), matching: find.byType(OutlinedButton));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            final rect = tester.getRect(button);
            expect(rect.left, greaterThanOrEqualTo(card.left));
            expect(rect.right, lessThanOrEqualTo(card.right));
          }
          final share = tester.widget<OutlinedButton>(find.ancestor(
              of: find.text('Share'), matching: find.byType(OutlinedButton)));
          expect(share.style!.foregroundColor!.resolve({}),
              const Color(0xFF101B3E));
          expect(share.style!.backgroundColor!.resolve({}),
              const Color(0xFFFFE16A));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
      'Another and Share keep exact displayed snapshot through '
      'live system theme changes', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    var current =
        _roast('politician', RoastMood.confident, text: 'First roast.');
    final next = _roast('politician', RoastMood.happy, text: 'Next roast.');
    Roast? shared;
    await tester.pumpWidget(_app(
      mode: ThemeMode.system,
      child: StatefulBuilder(
          builder: (context, setState) => ForecastRoastCard(
                persona: RoastPersonas.byId('politician').toDayMakerPersona(),
                roast: current,
                onNewRoast: () => setState(() => current = next),
                onShare: () => shared = current,
              )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another'));
    await tester.pumpAndSettle();
    expect(find.text('“Next roast.”'), findsOneWidget);
    expect(find.text('“First roast.”'), findsNothing);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(tester.widget<DmRoastSurface>(find.byType(DmRoastSurface)).colors,
        DMRoastColors.dark);
    expect(
        tester.widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait)).mood,
        RoastMood.happy);
    await tester.tap(find.text('Share'));
    expect(shared, same(next));
    expect(current, same(next));
    expect(tester.takeException(), isNull);
  });
}
