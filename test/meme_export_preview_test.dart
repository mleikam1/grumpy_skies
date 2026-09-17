import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_service.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_export_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xffabcabc), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(3, 2);
    png = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });

  Future<void> show(WidgetTester tester, _Store store, _Adapter adapter) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MemeExportPreview(
      document: MemeDocument.blank(name: 'Rain / café'),
      png: png,
      exports: MemeExportService(adapter: adapter),
      store: store,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('PNG saves while the independent project backup is pending',
      (tester) async {
    final store = _Store()..pending = Completer<Uint8List>();
    final adapter = _Adapter();
    await show(tester, store, adapter);
    expect(store.backups, 1);
    expect(find.text('Preparing project backup…'), findsOneWidget);
    await tester.tap(find.text('Save Image'));
    await tester.pumpAndSettle();
    expect(adapter.savedImages, 1);
    expect(find.text('Image saved to Photos.'), findsOneWidget);
    store.pending!.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(find.text('Save Project Backup'), findsOneWidget);
  });

  testWidgets('backup error leaves PNG usable and exposes an independent retry',
      (tester) async {
    final store = _Store()
      ..backupError = const MemeStorageException('Backup exceeds 64 MB.');
    final adapter = _Adapter();
    await show(tester, store, adapter);
    expect(find.textContaining('Backup exceeds 64 MB.'), findsOneWidget);
    expect(find.text('Retry Project Backup'), findsOneWidget);
    await tester.tap(find.text('Save Image'));
    await tester.pumpAndSettle();
    expect(adapter.savedImages, 1);
    expect(find.text('Image saved to Photos.'), findsOneWidget);
    store.backupError = null;
    await tester.tap(find.text('Retry Project Backup'));
    await tester.pumpAndSettle();
    expect(store.backups, 2);
    expect(adapter.savedBackups, 0);
    expect(find.text('Save Project Backup'), findsOneWidget);
    await tester.tap(find.text('Save Project Backup'));
    await tester.pumpAndSettle();
    expect(adapter.savedBackups, 1);
    expect(find.text('Project backup saved.'), findsOneWidget);
  });

  testWidgets(
      'a completed image transfer stays successful when history storage fails',
      (tester) async {
    final store = _Store()
      ..historyError = const MemeStorageException('Storage full.');
    final adapter = _Adapter();
    await show(tester, store, adapter);
    await tester.tap(find.text('Save Image'));
    await tester.pumpAndSettle();
    expect(adapter.savedImages, 1);
    expect(find.text('Image saved to Photos.'), findsOneWidget);
    expect(find.textContaining('recent export history could not be updated'),
        findsOneWidget);
    expect(find.textContaining('Could not finish:'), findsNothing);
    expect(store.lastRecord!.fileName, 'Rain___caf_.png');
  });

  testWidgets(
      'Share calls the prepared PNG adapter directly and handles cancellation',
      (tester) async {
    final store = _Store()..pending = Completer<Uint8List>();
    final adapter = _Adapter();
    await show(tester, store, adapter);
    await tester.tap(find.text('Share'));
    expect(adapter.shares, 1);
    expect(adapter.sharedBytes, same(png));
    expect(adapter.origin!.width, greaterThan(0));
    expect(adapter.origin!.height, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('Share cancelled.'), findsOneWidget);
    expect(store.lastRecord, isNull);
    store.pending!.complete(Uint8List.fromList([1]));
    await tester.pumpAndSettle();
  });
}

class _Store extends MemeStore {
  _Store() : super(MemoryMemeBackend());
  int backups = 0;
  Object? backupError, historyError;
  Completer<Uint8List>? pending;
  MemeExportRecord? lastRecord;

  @override
  Future<Uint8List> exportBackup(MemeDocument document) async {
    backups++;
    if (backupError != null) throw backupError!;
    if (pending != null) return pending!.future;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> recordExport(MemeExportRecord record) async {
    lastRecord = record;
    if (historyError != null) throw historyError!;
  }
}

class _Adapter implements MemeExportAdapter {
  int savedImages = 0, savedBackups = 0, shares = 0;
  Uint8List? sharedBytes;
  Rect? origin;

  @override
  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName) async {
    savedImages++;
    return const MemeTransferResult(
        MemeTransferStatus.saved, 'Image saved to Photos.');
  }

  @override
  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
      {Rect? origin}) async {
    savedBackups++;
    return const MemeTransferResult(
        MemeTransferStatus.saved, 'Project backup saved.');
  }

  @override
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
      {Rect? origin}) {
    shares++;
    sharedBytes = bytes;
    this.origin = origin;
    return Future.value(const MemeTransferResult(
        MemeTransferStatus.cancelled, 'Share cancelled.'));
  }
}
