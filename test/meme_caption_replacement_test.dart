import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_document_canvas.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = MemeCatalog.fromJson(
      jsonDecode(File(MemeCatalog.catalogAsset).readAsStringSync())
          as Map<String, dynamic>,
      jsonDecode(File(MemeCatalog.stickersAsset).readAsStringSync())
          as Map<String, dynamic>);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'),
            (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'), null);
  });

  Future<MemeDocumentCanvas> reopen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = catalog.templates.first.createDocument();
    final saved = original.copyWith(layers: [
      original.layers.first.copyWith(text: 'My carefully written setup'),
      original.layers.last.copyWith(text: 'My carefully written punchline ☔'),
    ]);
    final store = MemeStore(MemoryMemeBackend());
    await store.save(saved);
    final registry = DisplayedRoastRegistry()
      ..publish(DisplayedRoastSnapshot(
        id: 'displayed_roast_42',
        text: 'Exact displayed roast, with Mixed Case ☁',
        personaId: 'grandpa',
        sourceKey: 'forecast',
        sourceLabel: 'Home',
        isSample: false,
        weatherSnapshot: const {'source': 'cached', 'temperature': 22},
      ));
    addTearDown(registry.dispose);
    await tester.runAsync(() async {
      await loadMemeFonts();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: registry,
          child: MaterialApp(
              theme: DMTheme.light, home: MemeGeneratorScreen(store: store))));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var attempt = 0; attempt < 40; attempt++) {
      await _settle(tester);
      if (find.byType(MemeLibrary).evaluate().isNotEmpty &&
          tester
              .widget<MemeLibrary>(find.byType(MemeLibrary))
              .drafts
              .isNotEmpty) {
        break;
      }
    }
    final library = tester.widget<MemeLibrary>(find.byType(MemeLibrary));
    expect(library.drafts.single.layers.first.text, saved.layers.first.text);
    library.onDraft(library.drafts.single);
    await _settle(tester);
    final canvas =
        tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    expect(canvas.editor.hasUserEdits, false,
        reason: 'This is a freshly reopened draft.');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      var flushed = false;
      store.flush().then((_) => flushed = true);
      for (var attempt = 0; attempt < 40 && !flushed; attempt++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(flushed, true);
    });
    return canvas;
  }

  testWidgets('reopened custom captions require confirmation before reroll',
      (tester) async {
    final canvas = await reopen(tester);
    final before = canvas.editor.document.toJson();
    await tester.tap(find.text('Reroll Caption'));
    await _settle(tester);
    expect(find.text('Reroll the captions?'), findsOneWidget);
    expect(canvas.editor.document.toJson(), before);
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(canvas.editor.document.toJson(), before);
    await tester.tap(find.text('Reroll Caption'));
    await _settle(tester);
    await tester.tap(find.text('Replace'));
    await _settle(tester);
    expect(canvas.editor.document.layers.first.text,
        isNot(before['layers'][0]['text']));
  });

  testWidgets(
      'reopened custom captions require confirmation before exact roast transfer',
      (tester) async {
    final canvas = await reopen(tester);
    final before = canvas.editor.document.toJson();
    await tester.tap(find.text('Use Current Roast'));
    await _settle(tester);
    await tester.tap(find.text('Exact displayed roast, with Mixed Case ☁'));
    await _settle(tester);
    expect(find.text('Use this roast?'), findsOneWidget);
    expect(canvas.editor.document.toJson(), before);
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(canvas.editor.document.toJson(), before);
    await tester.tap(find.text('Use Current Roast'));
    await _settle(tester);
    await tester.tap(find.text('Exact displayed roast, with Mixed Case ☁'));
    await _settle(tester);
    await tester.tap(find.text('Replace'));
    await _settle(tester);
    expect(canvas.editor.document.layers.last.text,
        'Exact displayed roast, with Mixed Case ☁');
    expect(canvas.editor.document.personaId, 'grandpa');
    expect(canvas.editor.document.weatherSnapshot!['temperature'], 22);
  });

  testWidgets(
      'locked caption refuses both replacement actions without changing pair or weather',
      (tester) async {
    final canvas = await reopen(tester);
    canvas.editor
        .updateLayer(canvas.editor.document.layers.last.copyWith(locked: true));
    await tester.pump();
    final before = canvas.editor.document.toJson();
    for (final action in ['Reroll Caption', 'Use Current Roast']) {
      await tester.tap(find.text(action));
      await _settle(tester);
      expect(
          find.text(
              'Unlock the caption layers in Layers before replacing this pair.'),
          findsWidgets);
      expect(canvas.editor.document.toJson(), before);
      expect(find.text('Choose the displayed roast'), findsNothing);
      expect(find.text('Reroll the captions?'), findsNothing);
    }
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  // Dialogs deliberately leave the operation spinner visible underneath.
  // Pump the transition without waiting for that indeterminate ticker.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}
