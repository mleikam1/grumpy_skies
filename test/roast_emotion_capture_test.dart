import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'package:grumpy_skies/models/daymaker_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';

const capture = bool.fromEnvironment('CAPTURE_EMOTIONS');
Future<void>? _fonts;
Future<void> loadFonts() => _fonts ??= () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font
            in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    }();

Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file =
        File('docs/ui_implementation/refinement/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final samples = <String, (String, RoastMood)>{
    'karen': (
      "I'd like to speak to the manager of this humidity.",
      RoastMood.complaining
    ),
    'frat_bro': ('Bro… this is elite patio weather.', RoastMood.hyped),
    'politician': (
      'Clear skies. We take full credit for this bipartisan sunshine.',
      RoastMood.confident
    ),
    'grandpa': ('Now this is porch-sittin’ weather.', RoastMood.cozy),
    'two_year_old': ('Yay! Splashy puddle day!', RoastMood.excited),
  };
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final entry in samples.entries) {
      testWidgets('$mode ${entry.key} real roast cards and expression gallery',
          (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final persona = RoastPersonas.byId(entry.key).toDayMakerPersona();
        final roast = Roast(
            id: 'capture-${entry.key}',
            personaId: entry.key,
            weatherSnapshotId: 'fixture',
            text: entry.value.$1,
            category: 'today',
            createdAt: ApprovedFixture.now,
            xpReward: 0,
            mood: entry.value.$2);
        Future<void> pump(Widget child) async {
          await tester.runAsync(() async {
            await loadFonts();
            await tester.pumpWidget(MaterialApp(
                theme: dark ? DMTheme.darkTheme : DMTheme.lightTheme,
                home: RepaintBoundary(
                    key: key,
                    child: Scaffold(
                        body: Padding(
                            padding: const EdgeInsets.all(18),
                            child: child)))));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 80));
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 35)));
          }
          expect(tester.takeException(), isNull);
        }

        await pump(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('DayMaker · Fixture preview',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 18),
          FeaturedRoastCard(
              persona: persona, roast: roast, weather: ApprovedFixture.weather),
          const SizedBox(height: 24),
          const Text('Today card',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ForecastRoastCard(
              persona: persona,
              roast: roast,
              onNewRoast: () {},
              onShare: () {}),
        ]));
        await save(tester, key, 'emotion_${mode}_${entry.key}');
        tester.view.physicalSize = const Size(780, 860);
        await pump(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${persona.name} · All ten expressions',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 14, children: [
            for (final mood in RoastMood.values)
              SizedBox(
                  width: 139,
                  child: Column(children: [
                    DmPersonaPortrait(
                        personaId: entry.key,
                        mood: mood,
                        width: 139,
                        height: 230),
                    const SizedBox(height: 6),
                    Text(mood.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ])),
          ]),
        ]));
        await save(tester, key, 'emotion_gallery_${mode}_${entry.key}');
      });
    }
  }
}
