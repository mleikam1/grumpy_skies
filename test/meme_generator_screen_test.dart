import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grumpy_skies/config/app_routes.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_service.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_document_canvas.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_export_preview.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_inspector.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
import 'package:grumpy_skies/monetization/widgets/ad_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lostDataChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.image_picker_android.ImagePickerApi.retrieveLostResults',
    StandardMessageCodec(),
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'),
            (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
            lostDataChannel, (_) async => <Object?>[null]);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(lostDataChannel, null);
  });

  for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0]) {
    testWidgets('library and template editor work at ${width.toInt()}px',
        (tester) async {
      final store = MemeStore(MemoryMemeBackend());
      await _pumpStudio(tester, store, width: width);
      if (width == 390 || width == 1280) {
        await _capture(tester, 'widget_library_${width.toInt()}.png');
      }
      expect(find.text('Make the forecast\nyour punchline.'), findsOneWidget);
      expect(find.text('Pro'), findsNothing);
      expect(find.text('Make One for Today'), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
      await _chooseStorm(tester);
      final canvas =
          tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
      expect(canvas.editor.document.templateId, 'storm_boss_cat');
      expect(canvas.editor.document.layers.first.text,
          'THE FORECAST SAID A LITTLE DRIZZLE');
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      if (width == 390 || width == 1280) {
        await _capture(tester, 'widget_editor_${width.toInt()}.png');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _flush(tester, store);
    });
  }

  testWidgets(
      'same studio route removes publisher ad before editing a saved meme',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    await _pumpStudio(tester, store, width: 1280);
    final library = tester.element(find.byType(MemeLibrary));
    await tester.scrollUntilVisible(find.byType(AdSection), 300,
        scrollable: find.byType(Scrollable).first);
    await _settle(tester);
    final slot = tester.element(find.byType(AdSection));
    final selected = tester
        .widget<MemeLibrary>(find.byType(MemeLibrary))
        .catalog
        .templates[5];
    expect(slot.mounted, isTrue);
    tester.widget<MemeLibrary>(find.byType(MemeLibrary)).onTemplate(selected);
    await _settle(tester);
    expect(library.mounted, isFalse);
    expect(slot.mounted, isFalse);
    expect(find.byType(AdSection), findsNothing);
    expect(find.byType(MemeDocumentCanvas), findsOneWidget);
    await tester.tap(find.text('Save Draft'));
    await _settle(tester);
    final draft = (await store.listDocuments()).single;
    expect(draft.templateId, selected.id);
    expect(draft.toJson().toString(), isNot(contains('Advertisements')));
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);
  });

  testWidgets('phone landscape and a keyboard-open tool sheet remain editable',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    await _pumpStudio(tester, store,
        width: 844,
        height: 390,
        initialRoast: DisplayedRoastSnapshot(
            id: 'landscape_roast',
            text: 'The clouds brought snacks.',
            personaId: 'karen',
            sourceKey: 'forecast',
            sourceLabel: 'Home',
            isSample: false));

    final editor = tester
        .widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas))
        .editor;
    await _show(tester, find.widgetWithText(ChoiceChip, 'Text'));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Text').first);
    await _settle(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final field = find.descendant(
        of: find.byType(BottomSheet), matching: _caption('Top caption'));

    await Scrollable.ensureVisible(tester.element(field), alignment: .1);
    await tester.pump();

    await tester.tap(field);

    await tester.pump();

    tester.testTextInput.enterText('Landscape weather jokes');

    await tester.pump();

    expect(editor.document.layers.first.text, 'Landscape weather jokes');
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(231));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());

    await _flush(tester, store);
  });

  testWidgets('caption case, line breaks, undo and restart preserve a draft',
      (tester) async {
    final backend = MemoryMemeBackend();
    final store = MemeStore(backend);
    await _pumpStudio(tester, store);
    await _chooseStorm(tester);
    final field = _caption('Top caption');
    await _show(tester, field);
    await tester.enterText(field, 'storm mode\nBring snacks ☔');
    await tester.pump();
    var canvas =
        tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    expect(
        canvas.editor.document.layers.first.text, 'storm mode\nBring snacks ☔');
    tester.testTextInput.hide();
    await _show(tester, find.byTooltip('Undo'), delta: -300);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(canvas.editor.document.layers.first.text,
        'THE FORECAST SAID A LITTLE DRIZZLE');
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(
        canvas.editor.document.layers.first.text, 'storm mode\nBring snacks ☔');
    await tester.tap(find.text('Save Draft'));
    await _settle(tester);
    final saved = (await store.listDocuments()).single;
    expect(saved.layers.first.text, 'storm mode\nBring snacks ☔');
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);

    // New store and widget instances reproduce app restart without keeping the
    // former editor or its in-memory undo stack alive.
    final restarted = MemeStore(backend);
    await _pumpStudio(tester, restarted);
    expect(
        tester.widget<MemeLibrary>(find.byType(MemeLibrary)).drafts.length, 1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    await _show(tester, find.text('My Memes'));
    await tester.tap(find.text('My Memes'));
    await _settle(tester);
    expect((await restarted.listDocuments()).map((d) => d.name),
        contains('Storm Boss Cat'));
    await _show(tester, find.text('Storm Boss Cat'));
    await tester.tap(find.text('Storm Boss Cat'));
    await _settle(tester);
    canvas = tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    expect(canvas.editor.document.id, saved.id);
    expect(
        canvas.editor.document.layers.first.text, 'storm mode\nBring snacks ☔');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, restarted);
  });

  testWidgets('favorites, search and empty My Memes are real local state',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    await _pumpStudio(tester, store);
    await _show(tester, find.text('My Memes'));
    await tester.tap(find.text('My Memes'));
    await _settle(tester);
    expect(find.textContaining('Your weather mischief starts here.'),
        findsOneWidget);
    await tester.tap(find.text('Templates'));
    await _settle(tester);
    await _search(tester, 'Storm Boss');
    await _show(tester, find.text('Storm Boss Cat'));
    await tester.tap(find.byTooltip('Favorite template'));
    await _settle(tester);
    expect(await store.favorites(), {'storm_boss_cat'});
    await _show(tester, find.text('Favorites'), delta: -300);
    await tester.tap(find.text('Favorites'));
    await _settle(tester);
    await _show(tester, find.text('Storm Boss Cat'));
    expect(find.byTooltip('Remove favorite'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove favorite'));
    await _settle(tester);
    expect(await store.favorites(), isEmpty);
    expect(find.textContaining('No templates here yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large text, reduced motion and keyboard leave captions usable',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    await _pumpStudio(tester, store,
        width: 320,
        textScale: 1.6,
        reduceMotion: true,
        initialRoast: DisplayedRoastSnapshot(
            id: 'large_text_source',
            text: 'A tiny rain cloud.',
            personaId: 'karen',
            sourceKey: 'forecast',
            sourceLabel: 'Home',
            isSample: false));
    expect(find.byTooltip('Dismiss message'), findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    final editor = tester
        .widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas))
        .editor;
    final field = _caption('Top caption');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await _show(tester, field);
    await tester.enterText(field, 'a small cloud\nwith BIG feelings');
    await tester.pump();
    expect(
        editor.document.layers.first.text, 'a small cloud\nwith BIG feelings');
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(900 - 280 + 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);
  });

  testWidgets(
      'exact source snapshot enters editor without synthetic roast text',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    final source = DisplayedRoastSnapshot(
      id: 'exact_displayed',
      text: 'Clouds, we talked about this.\nBring snacks ☔',
      personaId: 'grandpa',
      sourceKey: 'forecast',
      sourceLabel: 'Home forecast',
      isSample: false,
    );
    await _pumpStudio(tester, store, initialRoast: source);
    final canvas =
        tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    expect(canvas.editor.document.layers.last.text, source.text);
    expect(canvas.editor.document.personaId, 'grandpa');
    expect(canvas.editor.document.weatherSnapshot, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);
  });

  testWidgets('explicit completed Done dismisses result and reaches Fun once',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    final adapter = _RecordingExportAdapter();
    final source = DisplayedRoastSnapshot(
        id: 'completion_source',
        text: 'The clouds brought snacks.',
        personaId: 'karen',
        sourceKey: 'forecast',
        sourceLabel: 'Forecast',
        isSample: false);
    final router = GoRouter(initialLocation: AppRoutes.memeGenerator, routes: [
      GoRoute(
          path: AppRoutes.fun,
          builder: (_, __) =>
              const Scaffold(body: Text('Fun completed destination'))),
      GoRoute(
          path: AppRoutes.memeGenerator,
          builder: (_, __) => MemeGeneratorScreen(
              initialRoast: source,
              store: store,
              exports: MemeExportService(adapter: adapter))),
    ]);
    addTearDown(router.dispose);
    await _pumpStudio(tester, store,
        initialRoast: source,
        app: MaterialApp.router(theme: _testTheme(), routerConfig: router));
    final canvas =
        tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    final savedId = canvas.editor.document.id;
    await tester.runAsync(() => canvas.cache.prepare(canvas.editor.document));
    await _show(tester, find.text('Export'), delta: -300);
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    for (var i = 0;
        i < 80 && find.byType(MemeExportPreview).evaluate().isEmpty;
        i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
    }
    await _settle(tester);
    await _show(tester, find.text('Save Image'));
    await tester.tap(find.text('Save Image'));
    await _settle(tester);
    await _show(tester, find.text('Done / Back to Fun'));
    await tester.tap(find.text('Done / Back to Fun'));
    // PNG preparation used runAsync; its Navigator continuation lives in that
    // real async zone. Let both it and Flutter's dismissal frames complete.
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      if (find.text('Fun completed destination').evaluate().isNotEmpty) break;
    }
    await _settle(tester);
    expect(find.text('Fun completed destination'), findsOneWidget);
    expect(find.byType(MemeExportPreview), findsNothing);
    expect((await store.load(savedId))!.id, savedId);
    expect(adapter.saves, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);
  });

  testWidgets('export preview saves actual PNG and reports share cancellation',
      (tester) async {
    final store = MemeStore(MemoryMemeBackend());
    final adapter = _RecordingExportAdapter();
    await _pumpStudio(tester, store,
        exports: MemeExportService(adapter: adapter));
    await _chooseStorm(tester);
    final canvas =
        tester.widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas));
    await tester.runAsync(() => canvas.cache.prepare(canvas.editor.document));
    await _show(tester, find.text('Export'), delta: -300);
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      if (find.byType(MemeExportPreview).evaluate().isNotEmpty) break;
    }
    expect(find.byType(MemeExportPreview), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    await _settle(tester);
    final preview =
        tester.widget<MemeExportPreview>(find.byType(MemeExportPreview));
    expect(preview.png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(ByteData.sublistView(preview.png).getUint32(16), 1080);
    expect(ByteData.sublistView(preview.png).getUint32(20), 1080);
    expect(adapter.saves, 0);
    expect(adapter.shares, 0);
    await _show(tester, find.text('Save Image'));
    await tester.tap(find.text('Save Image'));
    await _settle(tester);
    expect(adapter.saves, 1);
    expect(adapter.savedBytes, preview.png);
    expect(find.text('Image saved.'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await _settle(tester);
    expect(adapter.shares, 1);
    expect(adapter.origin, isNotNull);
    expect(adapter.origin!.width, greaterThan(0));
    expect(adapter.origin!.height, greaterThan(0));
    expect(find.text('Sharing cancelled.'), findsOneWidget);
    await tester.tap(find.text('Save Project Backup'));
    await _settle(tester);
    expect(adapter.backups, 1);
    expect(adapter.backupBytes, isNotEmpty);
    await tester.tap(find.text('Continue Editing'));
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.byType(MemeDocumentCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await _flush(tester, store);
  });
}

Future<void> _pumpStudio(
  WidgetTester tester,
  MemeStore store, {
  double width = 390,
  double height = 900,
  double textScale = 1,
  bool reduceMotion = false,
  DisplayedRoastSnapshot? initialRoast,
  MemeExportService? exports,
  Widget? app,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final expectedDrafts = (await store.listDocuments()).length;
  await tester.runAsync(loadMemeFonts);
  if (Platform.environment['MEME_TEST_FONT_DIR'] != null) {
    await tester.runAsync(() async {
      final fontDir = Platform.environment['MEME_TEST_FONT_DIR']!;
      for (final entry in {
        'Ahem': 'Roboto-Regular.ttf',
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf'
      }.entries) {
        final font = FontLoader(entry.key)
          ..addFont(File('$fontDir/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)));
        await font.load();
      }
    });
  }
  await tester.runAsync(() async {
    await tester.pumpWidget(RepaintBoundary(
        key: _surfaceKey,
        child: app ??
            MaterialApp(
              key: UniqueKey(),
              theme: _testTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: reduceMotion,
                ),
                child: child!,
              ),
              home: MemeGeneratorScreen(
                  store: store, initialRoast: initialRoast, exports: exports),
            )));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    if (initialRoast != null &&
        find.byType(MemeDocumentCanvas).evaluate().isNotEmpty) {
      break;
    }
    if (initialRoast == null &&
        find.byType(MemeLibrary).evaluate().isNotEmpty &&
        tester.widget<MemeLibrary>(find.byType(MemeLibrary)).drafts.length ==
            expectedDrafts) {
      break;
    }
  }
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String value) async {
  final search = find.byWidgetPredicate((widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'Find a template, weather, or mood');
  await tester.ensureVisible(search);
  await tester.enterText(search, value);
  await _settle(tester);
}

Future<void> _chooseStorm(WidgetTester tester) async {
  await _search(tester, 'Storm Boss');
  await _show(tester, find.text('Storm Boss Cat'));
  await tester.tap(find.text('Storm Boss Cat'));
  await _settle(tester);
}

Future<void> _show(WidgetTester tester, Finder target,
    {double delta = 300}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  for (var attempt = 0; attempt < 40; attempt++) {
    final elements = target.evaluate().toList();
    if (elements.isNotEmpty) {
      await Scrollable.ensureVisible(elements.first, alignment: .5);
      await _settle(tester);
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
    await tester.drag(find.byType(Scrollable).first, Offset(0, -delta));
    await _settle(tester);
  }
  expect(target.hitTestable(), findsWidgets,
      reason: 'The control should be reachable by scrolling.');
}

Finder _caption(String label) => find.descendant(
      of: find.byWidgetPredicate(
          (widget) => widget is CaptionInput && widget.label == label),
      matching: find.byType(TextField),
    );

class _RecordingExportAdapter implements MemeExportAdapter {
  int saves = 0, shares = 0, backups = 0;
  Uint8List? savedBytes, backupBytes;
  Rect? origin;
  @override
  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName) async {
    saves++;
    savedBytes = bytes;
    return const MemeTransferResult(MemeTransferStatus.saved, 'Image saved.');
  }

  @override
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
      {Rect? origin}) async {
    shares++;
    this.origin = origin;
    return const MemeTransferResult(
        MemeTransferStatus.cancelled, 'Sharing cancelled.');
  }

  @override
  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
      {Rect? origin}) async {
    backups++;
    backupBytes = bytes;
    return const MemeTransferResult(MemeTransferStatus.saved, 'Backup saved.');
  }
}

final _surfaceKey = GlobalKey();
Future<void> _capture(WidgetTester tester, String name) async {
  final folder = Platform.environment['MEME_ARTIFACT_DIR'];
  if (folder == null) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = _surfaceKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    await Directory(folder).create(recursive: true);
    await File('$folder/$name').writeAsBytes(bytes, flush: true);
    image.dispose();
  });
}

Future<void> _flush(WidgetTester tester, MemeStore store) async {
  var done = false;
  Object? failure;
  store.flush().then((_) => done = true, onError: (Object error) {
    failure = error;
    done = true;
  });
  for (var attempt = 0; attempt < 40 && !done; attempt++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  expect(failure, isNull);
  expect(done, true,
      reason: 'Queued local saves must complete after the editor closes.');
}

ThemeData _testTheme() {
  final base = DMTheme.light;
  if (Platform.environment['MEME_TEST_FONT_DIR'] == null) return base;
  TextStyle font(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(fontFamily: 'Roboto');
  ButtonStyle? button(ButtonStyle? style) => style?.copyWith(
      textStyle: WidgetStatePropertyAll(font(style.textStyle?.resolve({}))));
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: font(base.appBarTheme.titleTextStyle),
        toolbarTextStyle: font(base.appBarTheme.toolbarTextStyle)),
    filledButtonTheme:
        FilledButtonThemeData(style: button(base.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: button(base.outlinedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: button(base.textButtonTheme.style)),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: button(base.elevatedButtonTheme.style)),
    chipTheme: base.chipTheme.copyWith(
        labelStyle: font(base.chipTheme.labelStyle),
        secondaryLabelStyle: font(base.chipTheme.secondaryLabelStyle)),
  );
}
