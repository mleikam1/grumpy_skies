import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_document_canvas.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_inspector.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

Future<void> _settleAssets(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pump();
}

Future<ApprovedPreviewSession> _preview(WidgetTester tester,
    {String route = AppRoutes.forecast,
    double textScale = 1,
    AppAppearance appearance = AppAppearance.light}) async {
  tester.view.physicalSize = const Size(390, 930);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session =
      ApprovedPreviewSession(initialLocation: route, appearance: appearance);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    await tester.pump();
  });
  await tester.runAsync(() async {
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
    await loadMemeFonts();
    await session.initialize();
    await tester
        .pumpWidget(session.build(textScale: textScale, reducedMotion: true));
  });
  await _settleAssets(tester);
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('primary navigation exposes labels, buttons and selected state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _preview(tester);
      for (var selected = 0; selected < 2; selected++) {
        final expectedLabel = selected == 0 ? 'Today tab' : 'Fun tab';
        for (final item in DmBottomNav.defaultItems) {
          final node =
              tester.getSemantics(find.bySemanticsLabel(item.semanticLabel));
          expect(node.flagsCollection.isButton, isTrue);
          expect(node.flagsCollection.isSelected == Tristate.isTrue,
              item.semanticLabel == expectedLabel);
        }
        if (selected == 0) {
          await tester.tap(find.bySemanticsLabel('Fun tab'));
          await _settleAssets(tester);
        }
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
        'header Settings gear is keyboard reachable and activates with ${key.keyLabel}',
        (tester) async {
      await _preview(tester);
      bool gearHasFocus() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<IconButton>()
              ?.tooltip ==
          'Settings';
      for (var i = 0; i < 15 && !gearHasFocus(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(gearHasFocus(), isTrue,
          reason: 'Settings must be reachable through normal Tab traversal.');
      await tester.sendKeyEvent(key);
      await _settleAssets(tester);
      expect(find.byType(SettingsScreenBody), findsOneWidget);
      expect(find.byType(DmBottomNav), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'theme changes preserve actual Today scroll, persona, roast and weather request count',
      (tester) async {
    final session = await _preview(tester);
    session.settings.setSelectedPersonaId('frat_bro');
    await _settleAssets(tester);
    final state = tester.state(find.byType(ForecastScreen));
    final roast = tester
        .widget<ForecastRoastCard>(find.byType(ForecastRoastCard))
        .roast
        .text;
    final weather = session.location.currentWeather;
    final requestCount = session.weather.requestCount;
    final todayScroll = find.byKey(const PageStorageKey('today-scroll'));
    await tester.drag(todayScroll, const Offset(0, -420));
    await tester.pumpAndSettle();
    final scrollFinder = find
        .descendant(of: todayScroll, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollFinder).position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    for (final appearance in [AppAppearance.dark, AppAppearance.light]) {
      session.settings.setAppearance(appearance);
      await _settleAssets(tester);
      expect(tester.state(find.byType(ForecastScreen)), same(state));
      expect(position.pixels, closeTo(offset, .01));
      expect(session.settings.selectedPersonaId, 'frat_bro');
      expect(session.location.currentWeather, same(weather));
      expect(session.weather.requestCount, requestCount);
      expect(session.router.routeInformationProvider.value.uri.path,
          AppRoutes.forecast);
      expect(
          tester
              .widget<ForecastRoastCard>(find.byType(ForecastRoastCard))
              .roast
              .text,
          roast);
      expect(
          Theme.of(tester.element(find.byType(ForecastScreen))).brightness,
          appearance == AppAppearance.dark
              ? Brightness.dark
              : Brightness.light);
      expect(tester.takeException(), isNull);
    }
  });

  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    for (final route in [AppRoutes.forecast, AppRoutes.roasts, AppRoutes.fun]) {
      testWidgets('$route supports 2x text in ${appearance.name} appearance',
          (tester) async {
        await _preview(tester,
            route: route, textScale: 2, appearance: appearance);
        expect(find.byType(DmBottomNav), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Traverse below the first viewport so retained secondary modules also lay out.
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'theme preserves actual meme draft and editable caption with keyboard inset',
      (tester) async {
    final session = await _preview(tester,
        route: '${AppRoutes.memeGenerator}?template=approved_current_mood');
    expect(find.byType(MemeDocumentCanvas), findsOneWidget);
    final editor = tester
        .widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas))
        .editor;
    final field = find.descendant(
        of: find.byWidgetPredicate((widget) =>
            widget is CaptionInput && widget.label == 'Top caption'),
        matching: find.byType(TextField));
    await Scrollable.ensureVisible(tester.element(field), alignment: .2);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(field), alignment: .2);
    await tester.enterText(field, 'Exact draft. Still editable.');
    await tester.pump();
    final document = editor.document.toJson();
    final undoCount = editor.undoCount;
    final requestCount = session.weather.requestCount;
    for (final appearance in [AppAppearance.dark, AppAppearance.light]) {
      session.settings.setAppearance(appearance);
      await _settleAssets(tester);
      expect(
          tester
              .widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas))
              .editor,
          same(editor));
      expect(editor.document.toJson(), document);
      expect(editor.undoCount, undoCount);
      expect(session.weather.requestCount, requestCount);
      expect(session.router.routeInformationProvider.value.uri.path,
          AppRoutes.memeGenerator);
      expect(tester.takeException(), isNull);
    }
    expect(editor.document.layers.first.text, 'Exact draft. Still editable.');
    expect(find.byType(DmBottomNav), findsNothing);
  });
}
