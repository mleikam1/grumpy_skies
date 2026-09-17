import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_io.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_export_service.dart';
import 'package:grumpy_skies/features/fun/meme/platform/meme_import_service.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:share_plus/share_plus.dart';

Future<Uint8List> makePng({int width = 3, int height = 2}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffaa88cc), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory shareTemp;
  setUp(() async {
    shareTemp = await Directory.systemTemp.createTemp('daymaker_share_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => shareTemp.path);
  });
  tearDown(() async {
    await shareTemp.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  test('picker cancellation does not create media or a draft', () async {
    final backend = MemoryMemeBackend();
    final service = MemeImportService(MemeStore(backend), picker: _Picker());
    expect(await service.pick(), isNull);
    expect(await backend.keys('media'), isEmpty);
    expect(await backend.keys('documents'), isEmpty);
  });

  test('permission denial and unsupported camera return actionable errors',
      () async {
    final picker = _Picker()
      ..error = PlatformException(code: 'photo_access_denied');
    final service =
        MemeImportService(MemeStore(MemoryMemeBackend()), picker: picker);
    await expectLater(
        service.pick(),
        throwsA(isA<MemeImportException>()
            .having((error) => error.permissionDenied, 'denied', true)));
    picker.supportsCamera = false;
    await expectLater(
        service.pick(camera: true), throwsA(isA<MemeImportException>()));
  });

  test('raster importer validates content, rejects corruption and bounds bytes',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final service = MemeImportService(store, picker: _Picker());
    await expectLater(
        service.importBytes(Uint8List.fromList('<svg/>'.codeUnits)),
        throwsA(isA<MemeImportException>()));
    await expectLater(service.importBytes(Uint8List(memeMaxImportBytes + 1)),
        throwsA(isA<MemeImportException>()));
    await expectLater(
        service.importBytes(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 1, 1, 1])),
        throwsA(isA<MemeImportException>()));
    expect(await store.backend.keys('media'), isEmpty);
  });

  test('large valid raster is downsampled and persisted as clean PNG pixels',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final service = MemeImportService(store, picker: _Picker());
    final imported =
        await service.importBytes(await makePng(width: 3000, height: 30));
    expect(imported.width, 2048);
    expect(imported.height, 20);
    final bytes = await store.getMedia(imported.mediaId);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(imported.assetRef, 'media:${imported.mediaId}');
  });

  test('pixel bomb headers are refused before image allocation', () async {
    final bytes = await makePng();
    final header = ByteData.sublistView(bytes);
    header.setUint32(16, 100000);
    header.setUint32(20, 100000);
    await expectLater(
        normalizeMemeImage(bytes),
        throwsA(isA<MemeImportException>().having((error) => error.message,
            'bounded dimensions', contains('40 million'))));
  });

  test('JPEG header reader accounts for portrait EXIF orientation', () {
    // APP1 Exif: little-endian TIFF, one orientation SHORT entry (6 = 90°).
    final bytes = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe1,
      0,
      34,
      69,
      120,
      105,
      102,
      0,
      0,
      73,
      73,
      42,
      0,
      8,
      0,
      0,
      0,
      1,
      0,
      0x12,
      1,
      3,
      0,
      1,
      0,
      0,
      0,
      6,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0xff,
      0xc0,
      0,
      8,
      8,
      0,
      20,
      0,
      40,
      1,
      0xff,
      0xd9,
    ]);
    expect(memeRasterDimensions(bytes), (20, 40));
  });

  test('JPEG decode normalizes EXIF orientation into metadata-free PNG pixels',
      () async {
    final result = await normalizeMemeImage(base64Decode(
        '/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/4AAQSkZJRgABAQAASABIAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgACAAMAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A87ooor+Xz+/D/9k='));
    expect((result.width, result.height), (8, 12));
    expect(latin1.decode(result.png), isNot(contains('Exif')));
  });

  test('Android lost-data recovery copies recovered photos into durable media',
      () async {
    final bytes = await makePng();
    final picker = _Picker()
      ..lost = [XFile.fromData(bytes, name: 'recovered.png')];
    final backend = MemoryMemeBackend();
    final service = MemeImportService(MemeStore(backend), picker: picker);
    final recovered = await service.recoverLostImages();
    expect(recovered, hasLength(1));
    expect(await MemeStore(backend).getMedia(recovered.single.mediaId),
        isNotEmpty);
    expect(picker.recoveryCalls, 1);
  });

  test(
      'real Photos adapter invokes permission and PNG save channels before success',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), (call) async {
      calls.add(call);
      return call.method == 'requestAccess' ? true : null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), null));
    final bytes = await makePng();
    final result =
        await MemeExportService(adapter: NativeMemeExportAdapter(mobile: true))
            .savePng(bytes, 'sky.png');
    expect(result.status, MemeTransferStatus.saved);
    expect(
        calls.map((call) => call.method), ['requestAccess', 'putImageBytes']);
    expect(calls.last.arguments['bytes'], bytes);
    expect(calls.last.arguments['name'], 'sky');
  });

  test(
      'Photos permission denial offers a file/share fallback without false success',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), (_) async {
      throw PlatformException(code: 'ACCESS_DENIED');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), null));
    final result = await NativeMemeExportAdapter(mobile: true)
        .savePng(await makePng(), 'sky.png');
    expect(result.status, MemeTransferStatus.denied);
    expect(result.completed, isFalse);
    expect(result.message, contains('Share'));
  });

  test('native share passes exact PNG, filename and iPad popover origin',
      () async {
    ShareParams? received;
    final adapter = NativeMemeExportAdapter(
        mobile: true,
        shareSender: (params) async {
          received = params;
          return const ShareResult('selected-app', ShareResultStatus.success);
        });
    final service = MemeExportService(adapter: adapter);
    final bytes = await makePng();
    const origin = ui.Rect.fromLTWH(100, 120, 48, 48);
    final result =
        await service.sharePng(bytes, '../../weather meme.png', origin: origin);
    expect(received!.sharePositionOrigin, origin);
    expect(await received!.files!.single.readAsBytes(), bytes);
    expect(received!.fileNameOverrides!.single, '______weather_meme.png');
    expect(result.status, MemeTransferStatus.shared);
    expect(result.message, isNot(contains('posted')));
  });

  test('share cancellations, unavailable targets and failures stay distinct',
      () async {
    final bytes = await makePng();
    for (final status in [
      ShareResultStatus.dismissed,
      ShareResultStatus.unavailable
    ]) {
      final adapter = NativeMemeExportAdapter(
          mobile: true, shareSender: (_) async => ShareResult('', status));
      final result = await adapter.sharePng(bytes, 'meme.png');
      expect(result.completed, isFalse);
      expect(
          result.status,
          status == ShareResultStatus.dismissed
              ? MemeTransferStatus.cancelled
              : MemeTransferStatus.unavailable);
    }
    final failed = NativeMemeExportAdapter(
        mobile: true, shareSender: (_) async => throw StateError('no target'));
    expect((await failed.sharePng(bytes, 'meme.png')).status,
        MemeTransferStatus.failed);
  });

  test('invalid export never reaches a platform adapter', () async {
    var calls = 0;
    final service = MemeExportService(
        adapter: NativeMemeExportAdapter(shareSender: (_) async {
      calls++;
      return const ShareResult('', ShareResultStatus.success);
    }));
    expect(
        () => service.sharePng(Uint8List(8), 'bad.png'), throwsFormatException);
    expect(calls, 0);
  });

  test(
      'native temporary share copies are bounded independently of saved projects',
      () async {
    final adapter = NativeMemeExportAdapter(
        mobile: true,
        shareSender: (_) async =>
            const ShareResult('', ShareResultStatus.dismissed));
    final png = await makePng();
    for (var i = 0; i < 15; i++) {
      await adapter.sharePng(png, 'meme_$i.png');
    }
    final copies =
        Directory('${shareTemp.path}/daymaker_meme_shares').listSync();
    expect(copies, hasLength(12));
  });
}

class _Picker implements MemePhotoPicker {
  XFile? file;
  List<XFile> lost = [];
  PlatformException? error;
  int recoveryCalls = 0;
  @override
  bool supportsCamera = true;
  @override
  Future<XFile?> pick({required bool camera}) async {
    if (error != null) throw error!;
    return file;
  }

  @override
  Future<List<XFile>> recoverLost() async {
    recoveryCalls++;
    return lost;
  }
}
