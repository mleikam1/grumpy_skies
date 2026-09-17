@TestOn('browser')
library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:grumpy_skies/features/fun/meme/platform/meme_raster.dart';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_types.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_web.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_indexeddb_backend.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:idb_shim/idb_browser.dart';

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xff336699), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(3, 2);
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return png;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real browser IndexedDB reopens the exact project and photo', () async {
    final name =
        'daymaker_browser_test_${DateTime.now().microsecondsSinceEpoch}';
    final store =
        MemeStore(IndexedDbMemeBackend(idbFactoryNative, databaseName: name));
    final png = await _png();
    final mediaId = await store.putMedia(png);
    final document = MemeDocument.blank()
        .copyWith(background: MemeBackground(assetRef: 'media:$mediaId'));
    await store.save(document);
    final reopened =
        MemeStore(IndexedDbMemeBackend(idbFactoryNative, databaseName: name));
    expect((await reopened.load(document.id))!.toJson(), document.toJson());
    expect(await reopened.getMedia(mediaId), png);
    final backup = await reopened.exportBackup(document);
    final imported = await reopened.importBackup(backup);
    expect(await reopened.missingMedia(imported), isEmpty);
    expect(imported.id, isNot(document.id));
    await reopened.delete(document.id);
    await reopened.delete(imported.id);
    await reopened.collectUnreferencedMedia({});
  });

  test('JPEG decode normalizes EXIF orientation into metadata-free PNG pixels',
      () async {
    final result = await normalizeMemeImage(base64Decode(
        '/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/4AAQSkZJRgABAQAASABIAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgACAAMAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A87ooor+Xz+/D/9k='));
    expect((result.width, result.height), (8, 12));
    expect(latin1.decode(result.png), isNot(contains('Exif')));
  });

  test('browser Save Image and Save Backup invoke real download handoffs',
      () async {
    final adapter = BrowserMemeExportAdapter();
    final png = await _png();
    final image = await adapter.savePng(png, 'daymaker-browser-test.png');
    expect(image.status, MemeTransferStatus.downloaded);
    final backup = await adapter.saveBackup(
        Uint8List.fromList('{}'.codeUnits), 'daymaker-browser-test.daymaker');
    expect(backup.status, MemeTransferStatus.downloaded);
  });

  test(
      'browser file sharing feature detection offers a download on desktop Chrome',
      () async {
    final result = await BrowserMemeExportAdapter()
        .sharePng(await _png(), 'daymaker-share-test.png');
    expect(result.status,
        anyOf(MemeTransferStatus.downloaded, MemeTransferStatus.unavailable));
    expect(result.message, isNot(contains('posted')));
  });
}
