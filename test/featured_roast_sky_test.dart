import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_mood_badge.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_surface.dart';

const _longRoast =
    'I have reviewed every cloud in this forecast, and I remain committed to '
    'a thorough investigation of whoever misplaced the sunshine before the '
    'committee had finished its very important afternoon meeting.';
const _longLocation =
    'A deliberately long selected location name, Greater Metropolitan District, United States';

Roast _roast(String persona, RoastMood mood, {bool long = true}) => Roast(
    id: 'sky-test-$persona',
    personaId: persona,
    weatherSnapshotId: 'sky-weather',
    text:
        long ? _longRoast : 'The sky gets one carefully considered compliment.',
    category: 'today',
    mood: mood,
    createdAt: ApprovedFixture.now,
    xpReward: 0);

WeatherBundle _weather() => WeatherBundle.fromJson({
      ...ApprovedFixture.weather.toJson(),
      'current': {
        ...ApprovedFixture.weather.current.toJson(),
        'locationName': _longLocation,
        'temperatureC': 17.25,
        'condition': 'Scattered clouds',
      },
    });

BoxDecoration _pillDecoration(WidgetTester tester, Type type) => tester
    .widget<Container>(find
        .descendant(of: find.byType(type), matching: find.byType(Container))
        .first)
    .decoration! as BoxDecoration;

Future<void> _pump(
  WidgetTester tester, {
  required String persona,
  required RoastMood mood,
  bool dark = false,
  double width = 390,
  double scale = 1,
  bool long = true,
  TemperatureUnit unit = TemperatureUnit.fahrenheit,
  ThemeMode? themeMode,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
    theme: DMTheme.light,
    darkTheme: DMTheme.dark,
    themeMode: themeMode ?? (dark ? ThemeMode.dark : ThemeMode.light),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: FeaturedRoastCard(
            key: const ValueKey('featured-sky'),
            persona: RoastPersonas.byId(persona).toDayMakerPersona(),
            roast: _roast(persona, mood, long: long),
            weather: _weather(),
            temperatureUnit: unit,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

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

  final moods = {
    'karen': RoastMood.annoyed,
    'frat_bro': RoastMood.hyped,
    'grandpa': RoastMood.cozy,
    'politician': RoastMood.confident,
    'two_year_old': RoastMood.happy,
  };

  for (final dark in [false, true]) {
    for (final entry in moods.entries) {
      testWidgets(
          'featured blue palette, original artwork and metadata: '
          '${entry.key} dark=$dark', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, persona: entry.key, mood: entry.value, dark: dark);
        final context = tester.element(find.byType(FeaturedRoastCard));
        final colors = context.dmRoastColors;
        final surface =
            tester.widget<DmRoastSurface>(find.byType(DmRoastSurface));
        expect(surface.colors, colors);
        expect(surface.padding, const EdgeInsets.all(18));
        expect(surface.borderRadius, BorderRadius.circular(22));
        expect(find.text('MEET YOUR FORECASTER'), findsOneWidget);
        final name = RoastPersonas.byId(entry.key).displayName;
        expect(find.text('$name.'), findsOneWidget);
        expect(find.text('“$_longRoast”'), findsOneWidget);
        expect(find.text('63° · Scattered clouds'), findsOneWidget);
        expect(find.text(_longLocation), findsOneWidget);
        for (final text in [
          'MEET YOUR FORECASTER',
          '63° · Scattered clouds',
          _longLocation
        ]) {
          expect(tester.widget<Text>(find.text(text)).style!.color,
              colors.textSecondary);
        }
        expect(tester.widget<Text>(find.text('$name.')).style!.color,
            colors.textPrimary);
        expect(tester.widget<Text>(find.text('“$_longRoast”')).style!.color,
            colors.textPrimary);
        expect(
            tester.widget<Divider>(find.byType(Divider)).color, colors.divider);
        final role = _pillDecoration(tester, DmPersonaTitleBadge);
        expect(role.color, colors.personaSurface);
        expect((role.border! as Border).top.color, colors.personaBorder);
        final roleBadge = tester
            .widget<DmPersonaTitleBadge>(find.byType(DmPersonaTitleBadge));
        expect(
            roleBadge.label,
            entry.key == 'grandpa'
                ? 'WEATHER WISEGUY'
                : RoastPersonas.byId(entry.key).badgeText);
        expect(tester.widget<Text>(find.text(roleBadge.label)).style!.color,
            colors.personaText);
        final mood = _pillDecoration(tester, DmRoastMoodBadge);
        expect(mood.color, colors.moodSurface);
        expect((mood.border! as Border).top.color, colors.moodBorder);
        expect(
            tester
                .widget<Text>(find.text(entry.value.name.toUpperCase()))
                .style!
                .color,
            colors.moodText);
        final portrait =
            tester.widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait));
        expect(portrait.personaId, entry.key);
        expect(portrait.mood, entry.value);
        expect(portrait.height, 180);
        final image = tester.widget<Image>(find.descendant(
            of: find.byType(DmPersonaPortrait), matching: find.byType(Image)));
        expect((image.image as AssetImage).assetName,
            DmPersonaPortrait.pathFor(entry.key, mood: entry.value));
        expect(image.color, isNull);
        expect(image.fit, BoxFit.contain);
        expect(find.byType(ColorFiltered), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [(320.0, 2.0), (768.0, 2.0), (320.0, 1.0)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'featured reflows long copy and location width=${size.$1} '
          'scale=${size.$2} dark=$dark', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final entry in moods.entries) {
          await _pump(tester,
              persona: entry.key,
              mood: entry.value,
              dark: dark,
              width: size.$1,
              scale: size.$2,
              unit: TemperatureUnit.celsius);
          expect(find.text('17° · Scattered clouds'), findsOneWidget);
          expect(find.text(_longLocation), findsOneWidget);
          expect(find.text('“$_longRoast”'), findsOneWidget);
          final card = tester.getRect(find.byType(FeaturedRoastCard));
          for (final text in find
              .descendant(
                  of: find.byType(FeaturedRoastCard),
                  matching: find.byType(Text))
              .evaluate()) {
            final paragraph = text.findRenderObject()! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(paragraph.size.width, lessThanOrEqualTo(card.width));
          }
          expect(
              tester
                  .widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait))
                  .height,
              155);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('active system/light/dark changes preserve the featured snapshot',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _pump(tester,
        persona: 'politician',
        mood: RoastMood.confident,
        long: false,
        themeMode: ThemeMode.system);
    final first =
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard));
    final light =
        tester.widget<DmRoastSurface>(find.byType(DmRoastSurface)).colors;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    final next =
        tester.widget<FeaturedRoastCard>(find.byType(FeaturedRoastCard));
    final dark =
        tester.widget<DmRoastSurface>(find.byType(DmRoastSurface)).colors;
    expect(dark, isNot(light));
    expect(next.roast, same(first.roast));
    expect(next.weather, same(first.weather));
    expect(next.roast.resolvedMood, first.roast.resolvedMood);
    expect(
        tester.widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait)).mood,
        RoastMood.confident);
    expect(tester.takeException(), isNull);
  });
}
