import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meme_document.dart';
import '../platform/meme_raster.dart';

typedef MemeMediaReader = Future<Uint8List?> Function(String id);

/// A bounded, disposable decode cache. Original bytes live in the media store.
class MemeImageCache extends ChangeNotifier {
  MemeImageCache(this.readMedia);
  final MemeMediaReader readMedia;
  final Map<String, ui.Image> images = {};
  final Map<String, int> _decodeEdges = {};
  final Map<String, int> _sourceEdges = {};
  final Set<String> missing = {};
  Future<void> _pending = Future.value();
  bool _closed = false;
  static const maxDecodedPixels = 16 * 1000 * 1000;
  int get decodedPixels =>
      images.values.fold(0, (sum, image) => sum + image.width * image.height);

  Future<void> prepare(MemeDocument document) {
    final refs = <String>{
      if (document.background.assetRef != null) document.background.assetRef!,
      for (final layer in document.layers)
        if (!layer.hidden && layer.assetRef != null) layer.assetRef!,
    };
    _pending = _pending.catchError((Object _) {}).then((_) async {
      final edge = math.min(
          1920, math.sqrt(maxDecodedPixels / math.max(1, refs.length)).floor());
      // Rebalance in both directions: bound memory as layers are added and
      // restore source detail when layers are removed before a later export.
      for (final ref in refs) {
        if (_closed) return;
        final existing = images[ref];
        if (existing != null &&
            (_decodeEdges[ref] == edge ||
                ((_sourceEdges[ref] ?? edge + 1) <= edge &&
                    math.max(existing.width, existing.height) ==
                        _sourceEdges[ref]))) {
          continue;
        }
        images.remove(ref)?.dispose();
        try {
          final bytes = ref.startsWith('assets/')
              ? (await rootBundle.load(ref)).buffer.asUint8List()
              : await readMedia(ref);
          if (bytes == null) throw const FormatException('Missing image');
          final dimensions = memeRasterDimensions(bytes);
          _sourceEdges[ref] = math.max(dimensions.$1, dimensions.$2);
          final scale =
              math.min(1.0, edge / math.max(dimensions.$1, dimensions.$2));
          final codec = await ui.instantiateImageCodec(bytes,
              targetWidth: math.max(1, (dimensions.$1 * scale).floor()),
              targetHeight: math.max(1, (dimensions.$2 * scale).floor()),
              allowUpscaling: false);
          try {
            final frame = await codec.getNextFrame();
            if (_closed) {
              frame.image.dispose();
              return;
            }
            images[ref] = frame.image;
            _decodeEdges[ref] = edge;
            missing.remove(ref);
          } finally {
            codec.dispose();
          }
        } catch (_) {
          missing.add(ref);
        }
      }
      // Evict only decoded copies; saved projects/media are never evicted.
      for (final ref in images.keys.toList()) {
        if (images.length <= 32 && decodedPixels <= maxDecodedPixels) break;
        if (!refs.contains(ref)) {
          images.remove(ref)?.dispose();
          _decodeEdges.remove(ref);
          _sourceEdges.remove(ref);
        }
      }
      if (!_closed) notifyListeners();
    });
    return _pending;
  }

  @override
  void dispose() {
    _closed = true;
    for (final image in images.values) {
      image.dispose();
    }
    images.clear();
    _decodeEdges.clear();
    _sourceEdges.clear();
    super.dispose();
  }
}

Future<void>? _fontsReady;
Future<void> loadMemeFonts() => _fontsReady ??= Future.wait([
      (FontLoader('MemeSans')
            ..addFont(rootBundle.load('assets/fonts/Nunito.ttf')))
          .load(),
      (FontLoader('MemeMono')
            ..addFont(rootBundle.load('assets/fonts/SpaceMono-Bold.ttf')))
          .load(),
    ]);

/// Preview and export both paint this exact document in 1080-wide coordinates.
class MemePainter extends CustomPainter {
  const MemePainter(this.document, this.images);
  final MemeDocument document;
  final Map<String, ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    final width = document.layout.pixelWidth.toDouble();
    final height = document.layout.pixelHeight.toDouble();
    canvas.save();
    canvas.scale(size.width / width, size.height / height);
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));
    final bg = document.background;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height), Paint()..color = Color(bg.color));
    final image = images[bg.assetRef];
    if (image != null) {
      final panels = document.layout == MemeLayout.twoPanel
          ? [
              Rect.fromLTWH(0, height * .27, width / 2, height * .68),
              Rect.fromLTWH(width / 2, height * .27, width / 2, height * .68)
            ]
          : [Rect.fromLTWH(0, 0, width, height)];
      for (final panel in panels) {
        _paintImage(canvas, image, panel,
            fit: bg.fit == 'cover' ? BoxFit.cover : BoxFit.contain,
            zoom: bg.zoom,
            panX: bg.panX,
            panY: bg.panY,
            rotation: bg.rotation,
            flipX: bg.flipX,
            flipY: bg.flipY,
            brightness: bg.brightness,
            contrast: bg.contrast);
      }
    }
    if (document.layout == MemeLayout.twoPanel) {
      canvas.drawLine(
          Offset(width / 2, 0),
          Offset(width / 2, height),
          Paint()
            ..color = const Color(0xff172c42)
            ..strokeWidth = 5);
    }
    for (final layer in document.layers) {
      if (layer.hidden) continue;
      final rect = Rect.fromLTWH(layer.x * width, layer.y * height,
          layer.width * width, layer.height * height);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(layer.rotation);
      final local = Rect.fromCenter(
          center: Offset.zero, width: rect.width, height: rect.height);
      switch (layer.type) {
        case MemeLayerType.text:
        case MemeLayerType.weatherBadge:
          _paintText(canvas, layer, local, width);
        case MemeLayerType.sticker:
        case MemeLayerType.image:
          final layerImage = images[layer.assetRef];
          if (layerImage != null) {
            _paintImage(canvas, layerImage, local,
                fit: layer.type == MemeLayerType.image
                    ? BoxFit.cover
                    : BoxFit.contain,
                zoom: layer.zoom,
                panX: layer.panX,
                panY: layer.panY,
                flipX: layer.flipX,
                flipY: layer.flipY,
                brightness: layer.brightness,
                contrast: layer.contrast);
          }
        case MemeLayerType.shape:
          final paint = Paint()..color = Color(layer.color);
          if (layer.shape == 'ellipse') {
            canvas.drawOval(local, paint);
          } else {
            canvas.drawRRect(
                RRect.fromRectAndRadius(local, const Radius.circular(18)),
                paint);
          }
      }
      canvas.restore();
    }
    if (document.watermark) {
      _label(canvas, 'DayMaker',
          Rect.fromLTWH(width - 220, height - 38, 192, 25), 18);
    }
    if (document.layers
        .any((l) => !l.hidden && l.type == MemeLayerType.weatherBadge)) {
      _label(
          canvas,
          document.weatherSnapshot?['source'] == 'sample'
              ? 'Sample weather • for fun'
              : 'OpenWeather • ${document.weatherSnapshot?['stale'] == true ? 'stale ' : ''}frozen snapshot',
          Rect.fromLTWH(20, height - 38, width - 270, 25),
          14);
    }
    canvas.restore();
  }

  static void _label(Canvas c, String value, Rect rect, double size) {
    final p = TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(
                fontFamily: 'MemeSans',
                fontWeight: FontWeight.w700,
                fontSize: size,
                color: const Color(0xff172c42))),
        textDirection: TextDirection.ltr);
    p.layout(maxWidth: rect.width);
    c.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(6)),
        Paint()..color = const Color(0xddfff8ec));
    p.paint(c, rect.topLeft);
    p.dispose();
  }

  static void _paintImage(Canvas canvas, ui.Image image, Rect rect,
      {BoxFit fit = BoxFit.contain,
      double zoom = 1,
      double panX = 0,
      double panY = 0,
      double rotation = 0,
      bool flipX = false,
      bool flipY = false,
      double brightness = 0,
      double contrast = 1}) {
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(rect.center.dx + panX * rect.width,
        rect.center.dy + panY * rect.height);
    canvas.rotate(rotation);
    canvas.scale(zoom * (flipX ? -1 : 1), zoom * (flipY ? -1 : 1));
    final fitted = applyBoxFit(
        fit, Size(image.width.toDouble(), image.height.toDouble()), rect.size);
    final src = Alignment.center.inscribe(fitted.source,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()));
    final dst = Rect.fromCenter(
        center: Offset.zero,
        width: fitted.destination.width,
        height: fitted.destination.height);
    final paint = Paint()..filterQuality = FilterQuality.high;
    if (brightness != 0 || contrast != 1) {
      paint.colorFilter =
          ColorFilter.matrix(imageAdjustmentMatrix(brightness, contrast));
    }
    canvas.drawImageRect(image, src, dst, paint);
    canvas.restore();
  }

  static List<double> imageAdjustmentMatrix(
      double brightness, double contrast) {
    final offset = 255 * brightness + 128 * (1 - contrast);
    return [
      contrast,
      0,
      0,
      0,
      offset,
      0,
      contrast,
      0,
      0,
      offset,
      0,
      0,
      contrast,
      0,
      offset,
      0,
      0,
      0,
      1,
      0
    ];
  }

  static TextPainter textLayout(MemeLayer layer, double width, double height,
      {double documentWidth = 1080, bool stroke = false}) {
    final style = layer.textStyle;
    final text = style.uppercase ? layer.text.toUpperCase() : layer.text;
    var fontSize = style.fontSize * documentWidth;
    TextPainter make(double size) {
      final base = TextStyle(
          fontFamily: style.fontFamily,
          fontFamilyFallback: const ['sans-serif'],
          fontSize: size,
          fontWeight: FontWeight
              .values[((style.fontWeight / 100).round() - 1).clamp(0, 8)],
          height: style.lineHeight,
          color: stroke ? null : Color(style.color),
          foreground: stroke
              ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = style.strokeWidth * documentWidth
                ..strokeJoin = StrokeJoin.round
                ..color = Color(style.strokeColor))
              : null,
          shadows: !stroke && style.shadow
              ? const [
                  Shadow(
                      color: Color(0x55000000),
                      blurRadius: 4,
                      offset: Offset(2, 3))
                ]
              : null);
      return TextPainter(
          text: TextSpan(text: text, style: base),
          textAlign: switch (style.alignment) {
            'left' => TextAlign.left,
            'right' => TextAlign.right,
            _ => TextAlign.center
          },
          textDirection: TextDirection.ltr)
        ..layout(minWidth: math.max(1, width), maxWidth: math.max(1, width));
    }

    var painter = make(fontSize);
    // No ellipsis, no truncation: shrink only as far as a readable export size.
    while (painter.height > height && fontSize > 14) {
      painter.dispose();
      fontSize = math.max(14, fontSize - 1);
      painter = make(fontSize);
    }
    return painter;
  }

  static void _paintText(
      Canvas canvas, MemeLayer layer, Rect rect, double width) {
    final padding = layer.textStyle.pillColor == null ? 0.0 : 10.0;
    final inner = rect.deflate(padding);
    if (layer.textStyle.pillColor != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)),
          Paint()..color = Color(layer.textStyle.pillColor!));
    }
    final painter =
        textLayout(layer, inner.width, inner.height, documentWidth: width);
    final offset = Offset(inner.left,
        inner.top + math.max(0, (inner.height - painter.height) / 2));
    if (layer.textStyle.strokeWidth > 0) {
      final stroke = textLayout(layer, inner.width, inner.height,
          documentWidth: width, stroke: true);
      stroke.paint(canvas, offset);
      stroke.dispose();
    }
    painter.paint(canvas, offset);
    painter.dispose();
  }

  List<String> get exportWarnings {
    final result = <String>[];
    for (final l in document.layers.where((l) => !l.hidden)) {
      if (l.assetRef != null && !images.containsKey(l.assetRef)) {
        result.add('An image is missing. Reimport it before exporting.');
      }
      if (l.type == MemeLayerType.text ||
          l.type == MemeLayerType.weatherBadge) {
        final padding = l.textStyle.pillColor == null ? 0 : 20;
        final p = textLayout(l, l.width * 1080 - padding,
            l.height * document.layout.pixelHeight - padding);
        if (p.height > l.height * document.layout.pixelHeight - padding + 1) {
          result.add(
              'A caption is too long for its box. Enlarge it or shorten the text.');
        }
        p.dispose();
      }
      final w = l.width * 1080, h = l.height * document.layout.pixelHeight;
      final rotatedW =
          w * math.cos(l.rotation).abs() + h * math.sin(l.rotation).abs();
      final rotatedH =
          h * math.cos(l.rotation).abs() + w * math.sin(l.rotation).abs();
      final cx = (l.x + l.width / 2) * 1080,
          cy = (l.y + l.height / 2) * document.layout.pixelHeight;
      if (cx - rotatedW / 2 < -1 ||
          cx + rotatedW / 2 > 1081 ||
          cy - rotatedH / 2 < -1 ||
          cy + rotatedH / 2 > document.layout.pixelHeight + 1) {
        result.add(
            'A layer extends past the canvas. Move or resize it before exporting.');
      }
    }
    if (document.background.assetRef != null &&
        !images.containsKey(document.background.assetRef)) {
      result.add('The background image is missing. Choose another background.');
    }
    return result.toSet().toList();
  }

  @override
  bool shouldRepaint(covariant MemePainter oldDelegate) => true;
}

Future<Uint8List> exportMemePng(
    MemeDocument document, MemeImageCache cache) async {
  await loadMemeFonts();
  await cache.prepare(document);
  final painter = MemePainter(document, cache.images);
  final warnings = painter.exportWarnings;
  if (warnings.isNotEmpty) throw StateError(warnings.join('\n'));
  final recorder = ui.PictureRecorder();
  painter.paint(
      Canvas(recorder),
      Size(document.layout.pixelWidth.toDouble(),
          document.layout.pixelHeight.toDouble()));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
        document.layout.pixelWidth, document.layout.pixelHeight);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed. Try again.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
