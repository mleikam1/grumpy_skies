import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_import_service.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_service.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_backend_io.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'native studio edits, saves, restarts photos and exports actual PNGs',
      (tester) async {
    final support = await getApplicationSupportDirectory();
    final verification = await Directory(
            '${support.path}/meme_verification_${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
    final store = MemeStore(FileMemeBackend(directory: verification));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MemeGeneratorScreen(store: store)));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Blank Canvas'), findsOneWidget);
    await tester.ensureVisible(find.text('Blank Canvas'));
    await tester.tap(find.text('Blank Canvas'));
    await tester.pumpAndSettle();
    final caption = find.byType(TextField).first;
    await tester.ensureVisible(caption);
    await tester.enterText(caption, 'MY FORECAST HAS OPINIONS');
    await tester.pump(const Duration(milliseconds: 900));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save Draft'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();
    await store.flush();
    final saved = (await store.listDocuments()).single;
    expect(
        saved.layers.any((layer) => layer.text == 'MY FORECAST HAS OPINIONS'),
        isTrue);

    // Recreate the repository and editor: no plugin channels are mocked.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final restarted = MemeStore(FileMemeBackend(directory: verification));
    expect((await restarted.load(saved.id))!.toJson(), saved.toJson());
    final catalog = await MemeCatalog.load();
    final background =
        (await rootBundle.load(catalog.templates.first.assetPath))
            .buffer
            .asUint8List();
    final photo = await MemeImportService(restarted).importBytes(background);
    final photoDraft = catalog.templates.first.createDocument().copyWith(
        name: 'Native photo restart verification',
        background: MemeBackground(assetRef: photo.assetRef));
    await restarted.save(photoDraft);
    final reopenedStore = MemeStore(FileMemeBackend(directory: verification));
    final reopened = (await reopenedStore.load(photoDraft.id))!;
    expect(await reopenedStore.missingMedia(reopened), isEmpty);
    final images = MemeImageCache(
        (ref) => reopenedStore.getMedia(ref.replaceFirst('media:', '')));
    for (final layout in [
      MemeLayout.square,
      MemeLayout.portrait,
      MemeLayout.story,
      MemeLayout.twoPanel
    ]) {
      final png =
          await exportMemePng(reopened.copyWith(layout: layout), images);
      expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(png);
      expect(header.getUint32(16), layout.pixelWidth);
      expect(header.getUint32(20), layout.pixelHeight);
      await File('${verification.path}/native_${layout.name}.png')
          .writeAsBytes(png);
    }
    images.dispose();
    final backup = await reopenedStore.exportBackup(reopened);
    await File('${verification.path}/native_photo.daymaker')
        .writeAsBytes(backup);
    final imported = await reopenedStore.importBackup(backup);
    expect(await reopenedStore.missingMedia(imported), isEmpty);

    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MemeGeneratorScreen(store: reopenedStore)));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('My Memes'));
    await tester.tap(find.text('My Memes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Native photo restart verification'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Native photo restart verification'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Your masterpiece is ready'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Save Image'), 250,
        scrollable: find.byType(Scrollable).first);
    debugPrint('MEME_PHOTOS_SAVE_REQUESTED');
    await tester.tap(find.text('Save Image'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Image saved to Photos.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    final screenshot = await binding.takeScreenshot('meme_native_export_saved');
    await File('${verification.path}/native_export_screen.png')
        .writeAsBytes(screenshot);
    // Opt-in host-assisted check: opens the real OS sheet without choosing a
    // recipient. Dismiss the native sheet within three minutes (Android Back or
    // iOS Close). The default integration run is otherwise unattended.
    if (const bool.fromEnvironment('MEME_EXERCISE_SHARE')) {
      final png =
          await File('${verification.path}/native_square.png').readAsBytes();
      final sharing = MemeExportService().sharePng(
          png, 'native_share_verification',
          origin: const Rect.fromLTWH(40, 100, 48, 48));
      debugPrint('MEME_SHARE_AWAITING_DISMISSAL');
      final result = await sharing.timeout(const Duration(minutes: 3));
      expect(result.status,
          anyOf(MemeTransferStatus.cancelled, MemeTransferStatus.unavailable));
      debugPrint('MEME_SHARE_RESULT=${result.status.name}');
    }
    // The host can pull these real device artifacts with adb run-as.
    debugPrint('MEME_VERIFICATION_ARTIFACTS=${verification.path}');
    if (const bool.fromEnvironment('MEME_HOLD_ARTIFACTS')) {
      await Future<void>.delayed(const Duration(seconds: 90));
    }
  });
}
