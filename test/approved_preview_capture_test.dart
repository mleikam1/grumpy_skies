import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_export_preview.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';

// Opt in to writing review artifacts; normal flutter test runs only assertions.
const _capture = bool.fromEnvironment('CAPTURE_APPROVED_UI');
const _captureRoot = 'docs/ui_implementation/screenshots/fixture';

Future<void>? _fontLoading;

// Keep engine font registrations stable across the entire capture suite.
Future<void> _loadFonts() => _fontLoading ??= _loadRegisteredFonts();

Future<void> _loadRegisteredFonts() async {
  // Widget tests default to Ahem unless the actual app font manifest is loaded.
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  await loadMemeFonts();
}

Future<void> _pumpPreview(
    WidgetTester tester, ApprovedPreviewSession session, GlobalKey boundary,
    {Size size = const Size(390, 930),
    double textScale = 1,
    bool reducedMotion = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await _loadFonts();
    await session.initialize();
    await tester.pumpWidget(session.build(
        captureKey: boundary,
        textScale: textScale,
        reducedMotion: reducedMotion));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  // Decode real bundled artwork without pumpAndSettle's endless animation trap.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 35)));
  }
  await tester.pump();
}

Future<void> _save(WidgetTester tester, GlobalKey boundary, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_captureRoot/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _finish(
    WidgetTester tester, ApprovedPreviewSession session) async {
  await tester.pumpWidget(const SizedBox.shrink());
  session.dispose();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production libraries never import approved preview fixtures', () {
    final violations = <String>[];
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.contains('/preview/') ||
          file.path.endsWith('/main_preview.dart')) {
        continue;
      }
      if (RegExp(
              r'''(?:import|export)\s+['"][^'"]*(?:approved_fixture|approved_preview)''')
          .hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty);
  });
  const mainRoutes = {
    'today': AppRoutes.forecast,
    'roasts': AppRoutes.roasts,
    'fun': AppRoutes.fun
  };
  const secondaryRoutes = {
    'settings': AppRoutes.settings,
    'about': AppRoutes.about,
    'radar': AppRoutes.radar,
    'roast_reveal': AppRoutes.roastReveal,
    'meme_library': AppRoutes.memeGenerator,
    'onboarding': AppRoutes.splash,
  };

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final route in {...mainRoutes, ...secondaryRoutes}.entries) {
      testWidgets('approved fixture $theme ${route.key} at 390x930',
          (tester) async {
        final session = ApprovedPreviewSession(
            initialLocation: route.value,
            appearance: dark ? AppAppearance.dark : AppAppearance.light);
        final boundary = GlobalKey();
        await _pumpPreview(tester, session, boundary);
        // Keep diagnostic pixels even when a layout assertion fails.
        await _save(tester, boundary, '${theme}_${route.key}');
        expect(tester.takeException(), isNull);
        if (route.value == AppRoutes.forecast) {
          expect(
              find.textContaining(ApprovedFixture.karenQuote), findsOneWidget);
          expect(session.weather.requestCount, 1);
        }
        if (route.value == AppRoutes.roasts) {
          expect(find.textContaining(ApprovedFixture.grandpaQuote),
              findsOneWidget);
        }
        if (route.value == AppRoutes.memeGenerator) {
          expect(find.byType(MemeLibrary), findsOneWidget);
        }
        await _finish(tester, session);
      });
    }
    for (final state in ['location_prompt', 'weather_error', 'offline']) {
      testWidgets('approved fixture $theme $state', (tester) async {
        final session = ApprovedPreviewSession(
            appearance: dark ? AppAppearance.dark : AppAppearance.light,
            hasWeatherLocation: state != 'location_prompt');
        session.weather.failRequests = state == 'weather_error';
        session.weather.offline = state == 'offline';
        final boundary = GlobalKey();
        await _pumpPreview(tester, session, boundary);
        await _save(tester, boundary, '${theme}_$state');
        expect(tester.takeException(), isNull);
        expect(session.network.blockedRequests, 0);
        await _finish(tester, session);
      });
    }
    testWidgets('approved fixture $theme meme editor and export',
        (tester) async {
      final session = ApprovedPreviewSession(
          initialLocation: AppRoutes.memeGenerator,
          appearance: dark ? AppAppearance.dark : AppAppearance.light);
      final boundary = GlobalKey();
      await _pumpPreview(tester, session, boundary);
      await tester.tap(find.text('Blank Canvas'));
      // Let the real editor autosave finish in the memory backend.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await session.memeStore.listDocuments(), isNotEmpty);
      await _save(tester, boundary, '${theme}_meme_editor');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Export'));
      for (var i = 0;
          i < 50 && find.byType(MemeExportPreview).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.byType(MemeExportPreview), findsOneWidget);
      await _save(tester, boundary, '${theme}_meme_export');
      expect(tester.takeException(), isNull);
      expect(session.network.blockedRequests, 0);
      await _finish(tester, session);
    });
  }

  testWidgets('approved fixture reduced motion', (tester) async {
    final session = ApprovedPreviewSession();
    final boundary = GlobalKey();
    await _pumpPreview(tester, session, boundary, reducedMotion: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(session.weather.requestCount, 1);
    await _save(tester, boundary, 'responsive_reduced_motion_today');
    await _finish(tester, session);
  });

  for (final entry in const {
    'narrow': (Size(320, 740), 1.0),
    'small': (Size(360, 740), 1.0),
    'wide_phone': (Size(430, 932), 1.0),
    'large_text': (Size(390, 930), 1.35),
    'tablet': (Size(768, 1024), 1.0),
    'desktop': (Size(1440, 900), 1.0),
  }.entries) {
    for (final route in mainRoutes.entries) {
      testWidgets('approved fixture ${route.key} ${entry.key}', (tester) async {
        final session = ApprovedPreviewSession(initialLocation: route.value);
        final boundary = GlobalKey();
        await _pumpPreview(tester, session, boundary,
            size: entry.value.$1, textScale: entry.value.$2);
        await _save(tester, boundary, 'responsive_${entry.key}_${route.key}');
        expect(tester.takeException(), isNull);
        await _finish(tester, session);
      });
    }
  }
}
