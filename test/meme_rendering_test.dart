import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/meme_editor_controller.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemeCatalog catalog;
  setUpAll(() async {
    catalog = await MemeCatalog.load();
    await loadMemeFonts();
  });

  test('all 15 templates render complete captions and genuine PNG images',
      () async {
    final cache = MemeImageCache((_) async => null);
    addTearDown(cache.dispose);
    final samples = <Uint8List>[];
    for (final template in catalog.templates) {
      final document = template.createDocument();
      await cache.prepare(document);
      expect(cache.missing, isEmpty, reason: template.id);
      expect(MemePainter(document, cache.images).exportWarnings, isEmpty,
          reason: template.id);
      final bytes = await exportMemePng(document, cache);
      _expectPng(bytes, 1080, 1080);
      samples.add(bytes);
      await _artifact('${template.id}.png', bytes);
    }
    expect(samples.length, 15);
    await _contactSheet(catalog, samples);
  });

  test('square, portrait, story and two-panel export exact sizes', () async {
    final cache = MemeImageCache((_) async => null);
    addTearDown(cache.dispose);
    final editor =
        MemeEditorController(catalog.templates.first.createDocument());
    addTearDown(editor.dispose);
    for (final layout in MemeLayout.values) {
      editor.setLayout(layout);
      final document = editor.document;
      final bytes = await exportMemePng(document, cache);
      _expectPng(bytes, 1080, layout.pixelHeight);
      final decoded = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await decoded.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, layout.pixelHeight);
        frame.image.dispose();
      } finally {
        decoded.dispose();
      }
      await _artifact('export_${layout.name}.png', bytes);
    }
  });

  test('text preserves Unicode, newlines and casing without ellipsis', () {
    const words = 'Storm mode ☔️\nCrème brûlée, 你好';
    const layer = MemeLayer(
      id: 'unicode',
      type: MemeLayerType.text,
      text: words,
      x: .1,
      y: .1,
      width: .8,
      height: .2,
      textStyle: MemeTextStyle(fontSize: .065),
    );
    final paragraph = MemePainter.textLayout(layer, 864, 216);
    expect(paragraph.text!.toPlainText(), words);
    expect(paragraph.ellipsis, isNull);
    expect(paragraph.didExceedMaxLines, false);
    expect(paragraph.height, lessThanOrEqualTo(216));
    paragraph.dispose();
    final uppercase = MemePainter.textLayout(
      layer.copyWith(textStyle: layer.textStyle.copyWith(uppercase: true)),
      864,
      216,
    );
    expect(uppercase.text!.toPlainText(), words.toUpperCase());
    uppercase.dispose();
  });

  test('overflow and missing media block export with recovery text', () async {
    final cache = MemeImageCache((_) async => null);
    addTearDown(cache.dispose);
    final document = MemeDocument.blank().copyWith(layers: [
      MemeLayer(
        id: 'too_long',
        type: MemeLayerType.text,
        x: .1,
        y: .1,
        width: .12,
        height: .02,
        text: List.filled(50, 'Absolutely soaking wet').join(' '),
      ),
    ]);
    expect(
        MemePainter(document, {}).exportWarnings.single, contains('too long'));
    await expectLater(exportMemePng(document, cache), throwsStateError);
    final missing = MemeDocument.blank().copyWith(
      background: const MemeBackground(assetRef: 'media:missing_photo'),
    );
    await expectLater(exportMemePng(missing, cache), throwsStateError);
    expect(cache.missing, contains('media:missing_photo'));
  });

  test('image adjustment matrix preserves alpha and predictable channels', () {
    final identity = MemePainter.imageAdjustmentMatrix(0, 1);
    expect(
        identity, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    final brighter = MemePainter.imageAdjustmentMatrix(.2, 1);
    expect(brighter[4], closeTo(51, .0001));
    expect(brighter[9], closeTo(51, .0001));
    expect(brighter[14], closeTo(51, .0001));
    expect(brighter.sublist(15), [0, 0, 0, 1, 0]);
    final contrast = MemePainter.imageAdjustmentMatrix(0, 2);
    expect(contrast[0], 2);
    expect(contrast[4], -128);
    // Mid-gray is unchanged by contrast around the documented 128 midpoint.
    expect(128 * contrast[0] + contrast[4], 128);
  });

  test('all 24 transparent stickers decode and render together', () async {
    final cache = MemeImageCache((_) async => null);
    addTearDown(cache.dispose);
    final document = MemeDocument.blank(name: '24 weather troublemakers')
        .copyWith(watermark: false, layers: [
      for (var i = 0; i < catalog.stickers.length; i++) ...[
        MemeLayer(
          id: 'sticker_$i',
          type: MemeLayerType.sticker,
          x: (i % 6) / 6 + .015,
          y: (i ~/ 6) / 4 + .025,
          width: .136,
          height: .17,
          assetRef: catalog.stickers[i].assetPath,
        ),
        MemeLayer(
          id: 'label_$i',
          type: MemeLayerType.text,
          x: (i % 6) / 6 + .008,
          y: (i ~/ 6) / 4 + .2,
          width: .15,
          height: .045,
          text: catalog.stickers[i].name,
          textStyle: const MemeTextStyle(fontSize: .019),
        ),
      ],
    ]);
    await cache.prepare(document);
    expect(cache.missing, isEmpty);
    expect(cache.images.length, 24);
    expect(MemePainter(document, cache.images).exportWarnings, isEmpty);
    final bytes = await exportMemePng(document, cache);
    _expectPng(bytes, 1080, 1080);
    await _artifact('stickers_rendered.png', bytes);
  });

  test('many active photos rebalance decoded cache within its pixel budget',
      () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xffa3d9b6), BlendMode.src);
    final picture = recorder.endRecording();
    final source = await picture.toImage(1920, 1920);
    final bytes = (await source.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    source.dispose();
    picture.dispose();
    final cache = MemeImageCache((_) async => bytes);
    addTearDown(cache.dispose);
    final document = MemeDocument.blank().copyWith(layers: [
      for (var i = 0; i < 6; i++)
        MemeLayer(
            id: 'photo_$i',
            type: MemeLayerType.image,
            x: (i % 3) / 3 + .01,
            y: (i ~/ 3) / 2 + .01,
            width: .3,
            height: .45,
            assetRef: 'media:photo_$i'),
    ]);
    // Exercise rebalancing of an image that was cached at full resolution.
    await cache
        .prepare(document.copyWith(layers: document.layers.take(1).toList()));
    expect(cache.images.values.single.width, 1920);
    await cache.prepare(document);
    expect(cache.images.length, 6);
    expect(cache.missing, isEmpty);
    expect(cache.decodedPixels,
        lessThanOrEqualTo(MemeImageCache.maxDecodedPixels));
    expect(cache.images.values.every((image) => image.width < 1920), true);
    expect(MemePainter(document, cache.images).exportWarnings, isEmpty);
    _expectPng(await exportMemePng(document, cache), 1080, 1080);
    // Removing layers restores detail without restarting the editor/cache.
    final singlePhoto =
        document.copyWith(layers: document.layers.take(1).toList());
    await cache.prepare(singlePhoto);
    expect(cache.images['media:photo_0']!.width, 1920);
    expect(cache.decodedPixels,
        lessThanOrEqualTo(MemeImageCache.maxDecodedPixels));
    _expectPng(await exportMemePng(singlePhoto, cache), 1080, 1080);
  });

  test('export pixels match the shared painter and have no selection chrome',
      () async {
    final cache = MemeImageCache((_) async => null);
    addTearDown(cache.dispose);
    final document = MemeDocument.blank().copyWith(
      watermark: false,
      background: const MemeBackground(color: 0xfffaf1de),
      layers: const [
        MemeLayer(
          id: 'solid',
          type: MemeLayerType.shape,
          x: .25,
          y: .25,
          width: .5,
          height: .5,
          color: 0xffefbb00,
        ),
      ],
    );
    final png = await exportMemePng(document, cache);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData())!.buffer.asUint8List();
    List<int> pixel(int x, int y) =>
        bytes.sublist((y * 1080 + x) * 4, (y * 1080 + x) * 4 + 4);
    expect(pixel(100, 100), [250, 241, 222, 255]);
    expect(pixel(540, 540), [239, 187, 0, 255]);
    // The editor's blue selection border is not part of the document painter.
    expect(pixel(270, 540), [239, 187, 0, 255]);
    frame.image.dispose();
    codec.dispose();
  });
}

void _expectPng(Uint8List bytes, int width, int height) {
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final header = ByteData.sublistView(bytes);
  expect(header.getUint32(16), width);
  expect(header.getUint32(20), height);
  expect(bytes.length, greaterThan(100));
}

Future<void> _artifact(String name, Uint8List bytes) async {
  final path = Platform.environment['MEME_ARTIFACT_DIR'];
  if (path == null) return;
  await Directory(path).create(recursive: true);
  await File('$path/$name').writeAsBytes(bytes, flush: true);
}

Future<void> _contactSheet(MemeCatalog catalog, List<Uint8List> samples) async {
  if (Platform.environment['MEME_ARTIFACT_DIR'] == null) return;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xffe6e0d5), BlendMode.src);
  for (var i = 0; i < samples.length; i++) {
    final codec = await ui.instantiateImageCodec(samples[i], targetWidth: 360);
    final frame = await codec.getNextFrame();
    final x = (i % 3) * 360.0;
    final y = (i ~/ 3) * 400.0;
    canvas.drawImage(frame.image, Offset(x, y), Paint());
    final label = TextPainter(
      text: TextSpan(
        text: catalog.templates[i].name,
        style: const TextStyle(
            fontFamily: 'MemeSans',
            fontSize: 19,
            color: Color(0xff172c42),
            fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 344);
    label.paint(canvas, Offset(x + 8, y + 366));
    label.dispose();
    frame.image.dispose();
    codec.dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 2000);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  await _artifact('all_15_rendered.png', bytes);
  image.dispose();
  picture.dispose();
}
