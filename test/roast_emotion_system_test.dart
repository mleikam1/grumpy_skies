import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_csv_builder.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_repository.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'package:grumpy_skies/models/daymaker_models.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/pack_roast_repository.dart';
import 'package:grumpy_skies/shared/assets/persona_emotion_assets.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_mood_badge.dart';

Roast example(String id, String text, {RoastMood? mood}) => Roast(
    id: 'emotion-$id',
    personaId: id,
    weatherSnapshotId: 'frozen-weather',
    text: text,
    category: 'today',
    createdAt: ApprovedFixture.now,
    xpReward: 0,
    mood: mood);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all fifty bundled emotion assets are distinct native transparent art',
      () async {
    final hashes = <String>{};
    for (final persona in RoastPersonas.supportedIds) {
      for (final mood in RoastMood.values) {
        final path = PersonaEmotionAssets.path(persona, mood);
        final data = await rootBundle.load(path);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        expect(hashes.add(sha256.convert(bytes).toString()), isTrue,
            reason: '$path must have its own expression artwork');
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThanOrEqualTo(1000), reason: path);
        expect(frame.image.height, greaterThanOrEqualTo(1000), reason: path);
        final rgba =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = rgba!.buffer.asUint8List();
        var transparent = 0;
        var nearOpaque = 0;
        for (var index = 3; index < pixels.length; index += 4) {
          if (pixels[index] == 0) transparent++;
          // Native cutouts can use alpha 250–254 inside the subject. Count
          // visible coverage without requiring an artificially flattened matte.
          if (pixels[index] >= 250) nearOpaque++;
        }
        expect(transparent, greaterThan(1000),
            reason: '$path needs a real transparent background');
        expect(nearOpaque, greaterThan(100000),
            reason: '$path must contain visible character art');
        frame.image.dispose();
        codec.dispose();
      }
    }
    expect(hashes, hasLength(50));
  });
  test('roast quote and small title text meet contrast on both card gradients',
      () {
    for (final colors in [DMSemanticColors.light, DMSemanticColors.dark]) {
      for (final surface in [
        ...colors.karenGradient.colors,
        ...colors.grandpaGradient.colors
      ]) {
        for (final ink in [colors.textPrimary, colors.textSecondary]) {
          final a = ink.computeLuminance();
          final b = surface.computeLuminance();
          final contrast =
              a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
      }
    }
  });

  test('required examples infer stable expressions and explicit mood wins', () {
    final cases = <(String, String, RoastMood)>[
      (
        'karen',
        'I’d like to speak to the manager of this humidity.',
        RoastMood.complaining
      ),
      ('frat-bro', 'Bro… this is elite patio weather.', RoastMood.hyped),
      ('old_grandpa', 'Now this is porch-sittin’ weather.', RoastMood.cozy),
      ('toddler', 'Yay! Splashy puddle day!', RoastMood.excited),
      ('politician', 'Trust me, victory is assured.', RoastMood.confident),
      ('karen', 'Ugh, this is ridiculous.', RoastMood.annoyed),
      ('frat_bro', 'I am disappointed. The rain ruined my day.', RoastMood.sad),
      ('grandpa', 'Be careful and stay safe.', RoastMood.worried),
      ('two_year_old', 'A lovely, beautiful day!', RoastMood.happy),
      ('unknown', 'The sky exists.', RoastMood.neutral),
    ];
    for (final (persona, quote, expected) in cases) {
      for (var render = 0; render < 5; render++) {
        expect(example(persona, quote).resolvedMood, expected);
      }
      expect(example(persona, quote, mood: RoastMood.neutral).resolvedMood,
          RoastMood.neutral);
    }
  });

  test('legacy lines, unfamiliar mood and explicit mood round trip safely', () {
    final pack = RoastPack.fromJson(jsonDecode(
        File('assets/roasts/roast_pack_v1.json').readAsStringSync()));
    for (final line in pack.roasts) {
      expect(line.mood, isNotNull);
      expect(RoastLine.fromJson(line.toJson()).mood, line.mood);
      final legacy = Map<String, dynamic>.from(line.toJson())..remove('mood');
      expect(RoastLine.fromJson(legacy).mood, isNull);
      legacy['mood'] = 'future-expression';
      expect(RoastLine.fromJson(legacy).mood, isNull);
    }
    final csv = const RoastPackCsvBuilder()
        .build(File('content/roasts/roasts_template.csv').readAsStringSync())
        .pack;
    expect(csv.roasts.map((r) => r.mood), pack.roasts.map((r) => r.mood));
    final r = example('toddler', 'Yay!', mood: RoastMood.happy);
    expect(r.toJson()['mood'], 'happy');
    expect(example('toddler', 'Yay!').toJson().containsKey('mood'), isFalse);
  });

  test('aliases resolve to fixed bundled paths and same-character fallback',
      () {
    expect(PersonaEmotionAssets.path('2-Year-Old', RoastMood.excited),
        'assets/personas/two_year_old/excited.png');
    expect(PersonaEmotionAssets.path('fratbro', RoastMood.hyped),
        'assets/personas/frat_bro/hyped.png');
    expect(PersonaEmotionAssets.fallbacks('old_grandpa', RoastMood.sad), [
      'assets/personas/grandpa/sad.png',
      'assets/personas/grandpa/neutral.png',
      'assets/approved_v1/personas/grandpa_portrait.png',
    ]);
    expect(
        PersonaEmotionAssets.fallbacks('karen', RoastMood.neutral).length, 2);
  });

  test(
      'shared snapshot freezes expression and registry notices an explicit change',
      () {
    DisplayedRoastSnapshot source(RoastMood mood) => DisplayedRoastSnapshot(
        id: 'same',
        text: 'Same exact quote.',
        personaId: 'old_grandpa',
        sourceKey: 'roasts',
        sourceLabel: 'Roasts',
        isSample: false,
        mood: mood);
    final registry = DisplayedRoastRegistry();
    var notifications = 0;
    registry.addListener(() => notifications++);
    final frozen = source(RoastMood.cozy);
    registry.publish(frozen);
    registry.publish(source(RoastMood.cozy));
    expect(notifications, 1);
    registry.publish(source(RoastMood.worried));
    expect(notifications, 2);
    expect(registry.choices.single.mood, RoastMood.worried);
    expect(frozen.mood, RoastMood.cozy);
    expect(frozen.personaId, 'grandpa');
    registry.dispose();
  });

  test('real pack selection and history carry editorial mood without reroll',
      () async {
    final repo = PackRoastRepository(
        packs: RoastPackRepository(), clock: () => ApprovedFixture.now);
    repo.setWeather(ApprovedFixture.weather, TemperatureUnit.fahrenheit);
    for (final id in RoastPersonas.supportedIds) {
      final first =
          await repo.getDailyRoast(personaId: id, weatherSnapshotId: 'same');
      expect(first.mood, isNotNull);
      expect(await repo.getDailyRoast(personaId: id, weatherSnapshotId: 'same'),
          same(first));
      repo.recordDisplayed(first);
      final second =
          await repo.nextRoast(personaId: id, weatherSnapshotId: 'same');
      expect(second.mood, isNotNull);
      expect(
          (await repo.getRoastHistory(personaId: id)).single.mood, first.mood);
    }
  });

  for (final dark in [false, true]) {
    for (final id in RoastPersonas.supportedIds) {
      testWidgets(
          '$id ${dark ? 'dark' : 'light'} long quote at 2x stays readable and actionable',
          (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final roast = example(
            id,
            'The weather has filed a formal complaint about this very long forecast. '
            'Bring a layer, check the sky, and take your time getting where you need to go.',
            mood: RoastMood.worried);
        var another = 0;
        var shared = 0;
        await tester.pumpWidget(MaterialApp(
            theme: dark ? DMTheme.darkTheme : DMTheme.lightTheme,
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: Column(children: [
                  ForecastRoastCard(
                      persona: RoastPersonas.byId(id).toDayMakerPersona(),
                      roast: roast,
                      onNewRoast: () => another++,
                      onShare: () => shared++),
                  FeaturedRoastCard(
                      persona: RoastPersonas.byId(id).toDayMakerPersona(),
                      roast: roast,
                      weather: ApprovedFixture.weather),
                ]))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            tester
                .widgetList<DmPersonaPortrait>(find.byType(DmPersonaPortrait))
                .every((portrait) => portrait.mood == RoastMood.worried),
            isTrue);
        expect(find.byType(DmRoastMoodBadge), findsNWidgets(2));
        await tester.ensureVisible(find.text('Another'));
        await tester.tap(find.text('Another'));
        await tester.ensureVisible(find.text('Share'));
        await tester.tap(find.text('Share'));
        expect(another, 1);
        expect(shared, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
