import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/config/wingman_brand.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import 'package:grumpy_skies/shared/widgets/wingman_logo.dart';

const _captureRoot = String.fromEnvironment('WINGMAN_BRAND_CAPTURE_ROOT');
Future<void>? _fonts;
Future<void> _loadFonts() => _fonts ??= () async {
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

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Wingman header dark=$dark width=$width scale=$scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 220 * scale);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final boundary = GlobalKey();
          await tester.runAsync(_loadFonts);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? DMTheme.dark : DMTheme.light,
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: DmPageHeader(),
                  ),
                ),
              ),
            ),
          ));
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel(WingmanBrand.name), findsOneWidget);
          expect(find.text(WingmanBrand.headerTagline), findsOneWidget);
          expect(find.text(WingmanBrand.tagline), findsNothing);
          expect(find.text('daymaker.'), findsNothing);
          final text = tester.renderObject<RenderParagraph>(
              find.text(WingmanBrand.headerTagline));
          expect(text.didExceedMaxLines, isFalse);
          final logo = tester.getRect(find.byType(WingmanLogo));
          final caption = tester.getRect(find.text(WingmanBrand.headerTagline));
          final settings = tester.getRect(find.byTooltip('Settings'));
          expect(caption.top, greaterThanOrEqualTo(logo.bottom));
          expect(caption.right, lessThanOrEqualTo(settings.left));
          expect(settings.width, greaterThanOrEqualTo(48));
          semantics.dispose();
          if (_captureRoot.isNotEmpty) {
            await tester.runAsync(() async {
              final render = boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 2);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File(
                  '$_captureRoot/header_${dark ? 'dark' : 'light'}'
                  '_${width.toInt()}_${scale == 1 ? 'normal' : 'large'}.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }

  testWidgets('Titled headers retain title, back action and Settings',
      (tester) async {
    final router = GoRouter(initialLocation: '/detail', routes: [
      GoRoute(
          path: '/detail',
          builder: (_, __) => const Scaffold(
              body: DmPageHeader(title: 'Forecast details', back: true))),
      GoRoute(
          path: AppRoutes.forecast,
          builder: (_, __) => const Text('Today destination')),
      GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const Text('Settings destination')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Forecast details'), findsOneWidget);
    expect(find.byType(WingmanLogo), findsNothing);
    expect(find.text(WingmanBrand.headerTagline), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Today destination'), findsOneWidget);
  });
}
