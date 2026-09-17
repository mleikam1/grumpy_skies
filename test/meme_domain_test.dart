import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/meme_editor_controller.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> rawCatalog, rawStickers;
  late MemeCatalog catalog;

  setUpAll(() {
    rawCatalog = jsonDecode(File(MemeCatalog.catalogAsset).readAsStringSync())
        as Map<String, dynamic>;
    rawStickers = jsonDecode(File(MemeCatalog.stickersAsset).readAsStringSync())
        as Map<String, dynamic>;
    catalog = MemeCatalog.fromJson(rawCatalog, rawStickers);
  });

  group('bundled starter catalog', () {
    test(
        'all original IDs, safe zones, 140 intact pairs and canonical personas',
        () {
      expect(catalog.templates.length, 15);
      expect(catalog.stickers.length, 24);
      expect(
          catalog.templates.expand((template) => template.captionPairs).length,
          90);
      expect(catalog.personaCaptions.length, 50);
      expect(catalog.allCaptions.length, 140);
      expect(catalog.allCaptions.map((pair) => pair.id).toSet().length, 140);
      expect(catalog.personaCaptions.map((pair) => pair.personaId).toSet(),
          RoastPersonas.supportedIds.toSet());
      for (final template in catalog.templates) {
        expect(template.captionPairs.length, 6);
        expect(template.defaultCaption.id, '${template.id}_01');
        final document = template.createDocument();
        expect(document.layers[0].text, template.defaultCaption.top);
        expect(document.layers[1].text, template.defaultCaption.bottom);
        expect(document.layers[0].role, 'top');
        expect(document.layers[1].role, 'bottom');
        expect(document.background.assetRef, template.assetPath);
        expect(document.layers.map((layer) => layer.textStyle.color),
            everyElement(0xff172c42));
        for (var i = 0; i < template.safeTextZones.length; i++) {
          expect(document.layers[i].x, template.safeTextZones[i].x);
          expect(document.layers[i].y, template.safeTextZones[i].y);
          expect(document.layers[i].width, template.safeTextZones[i].width);
          expect(document.layers[i].height, template.safeTextZones[i].height);
        }
      }
      expect(catalog.templateById('storm_boss_cat')!.defaultCaption.top,
          'THE FORECAST SAID A LITTLE DRIZZLE');
      expect(
          catalog.templateById('temperature_whiplash')!.defaultCaption.bottom,
          'HUMAN BAKED POTATO BY LUNCH.');
      expect(catalog.templateById('unknown'), isNull);
    });

    test(
        'every runtime image decodes, has expected dimensions and original hash',
        () async {
      expect(catalog.assetPaths.length, 54);
      for (final path in catalog.assetPaths) {
        expect(path.contains('examples'), isFalse);
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        final image = (await codec.getNextFrame()).image;
        final size = path.contains('thumbnails')
            ? 288
            : path.contains('stickers')
                ? 512
                : 1080;
        expect(image.width, size, reason: path);
        expect(image.height, size, reason: path);
        if (path.contains('stickers')) {
          final rgba =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          expect(rgba!.getUint8(3), 0,
              reason: 'Sticker corners must be transparent: $path');
        }
        image.dispose();
        codec.dispose();
      }
      for (final raw in [
        ...rawCatalog['templates'] as List,
        ...rawStickers['stickers'] as List
      ]) {
        final bytes = File(raw['assetPath'] as String).readAsBytesSync();
        expect(sha256.convert(bytes).toString(), raw['sha256']);
        expect(File('docs/meme-assets/${raw['sourceSvgPath']}').existsSync(),
            isTrue);
      }
    });

    test('duplicate IDs, invalid safe zones and unknown schema/personas fail',
        () {
      final duplicate = _clone(rawCatalog);
      (duplicate['templates'] as List)
          .add((duplicate['templates'] as List).first);
      expect(() => MemeCatalog.fromJson(duplicate, rawStickers),
          throwsFormatException);
      final badZone = _clone(rawCatalog);
      badZone['templates'][0]['safeTextZones'][0]['width'] = 1.1;
      expect(() => MemeCatalog.fromJson(badZone, rawStickers),
          throwsFormatException);
      final badPersona = _clone(rawCatalog);
      badPersona['personaCaptions'][0]['seedPersonaId'] = 'unrecognized';
      expect(() => MemeCatalog.fromJson(badPersona, rawStickers),
          throwsFormatException);
      expect(
          () => MemeCatalog.fromJson(
              {...rawCatalog, 'schemaVersion': 42}, rawStickers),
          throwsFormatException);
    });
  });

  group('immutable versioned document', () {
    test(
        'roundtrip preserves all layer types, Unicode, styles and photo transforms',
        () {
      final document = catalog.templates.first.createDocument().copyWith(
            layers: [
              for (final type in MemeLayerType.values)
                MemeLayer(
                  id: type.name,
                  type: type,
                  x: .1,
                  y: .2,
                  width: .3,
                  height: .4,
                  rotation: .25,
                  text: 'Cloud café ☁️\n你好',
                  textStyle: const MemeTextStyle(
                      fontFamily: 'MemeMono',
                      pillColor: 0xff123456,
                      uppercase: false,
                      lineHeight: 1.3,
                      strokeWidth: .002,
                      shadow: true),
                  assetRef: type == MemeLayerType.image
                      ? 'media:photo1'
                      : type == MemeLayerType.sticker
                          ? catalog.stickers.first.assetPath
                          : null,
                  zoom: 1.5,
                  panX: -.3,
                  panY: .4,
                  flipX: true,
                  flipY: true,
                  brightness: -.2,
                  contrast: 1.4,
                  locked: true,
                  hidden: true,
                  shape: 'ellipse',
                ),
            ],
            background: const MemeBackground(
                assetRef: 'media:background1',
                fit: 'cover',
                zoom: 2,
                flipX: true),
            layout: MemeLayout.portrait,
            weatherSnapshot: {
              'temperature': 17,
              'tags': ['rain'],
              'source': 'cached'
            },
          );
      final restored = MemeDocument.fromJson(_clone(document.toJson()));
      expect(restored.toJson(), document.toJson());
      expect(restored.mediaIds, {'photo1', 'background1'});
      expect(restored.pixelWidth, 1080);
      expect(restored.pixelHeight, 1350);
      expect(restored.layers.first.text, 'Cloud café ☁️\n你好');
      expect(() => restored.layers.clear(), throwsUnsupportedError);
      expect(() => (restored.weatherSnapshot!['tags'] as List).clear(),
          throwsUnsupportedError);
      expect(() => restored.weatherSnapshot!['temperature'] = 2,
          throwsUnsupportedError);
      expect(
          restored
              .copyWith(weatherSnapshot: null, templateId: null)
              .weatherSnapshot,
          isNull);
      expect(restored.copyWith(templateId: null).templateId, isNull);
      expect(
          restored.layers.first.textStyle.copyWith(pillColor: null).pillColor,
          isNull);
    });

    test(
        'version 1 migrates weather and background while future versions fail safely',
        () {
      final old = catalog.templates.first.createDocument().toJson();
      old['schemaVersion'] = 1;
      old['background'] = catalog.templates.first.assetPath;
      old.remove('weatherSnapshot');
      old['weather'] = {'temperature': 12};
      old.remove('visualStyle');
      final migrated = MemeDocument.fromJson(old);
      expect(migrated.weatherSnapshot!['temperature'], 12);
      expect(migrated.background.fit, 'contain');
      expect(migrated.toJson()['schemaVersion'], MemeDocument.schemaVersion);
      expect(() => MemeDocument.fromJson({...old, 'schemaVersion': 999}),
          throwsFormatException);
    });

    test(
        'bad geometry, duplicate IDs, invalid paths, missing asset refs and privacy fields fail',
        () {
      final original = catalog.templates.first.createDocument().toJson();
      for (final field in ['x', 'y', 'width', 'height']) {
        final invalid = _clone(original);
        invalid['layers'][0][field] = double.nan;
        expect(() => MemeDocument.fromJson(invalid), throwsFormatException,
            reason: field);
      }
      final offscreen = _clone(original);
      offscreen['layers'][0]['x'] = .9;
      expect(() => MemeDocument.fromJson(offscreen), throwsFormatException);
      final duplicate = _clone(original);
      duplicate['layers'][1]['id'] = duplicate['layers'][0]['id'];
      expect(() => MemeDocument.fromJson(duplicate), throwsFormatException);
      for (final path in [
        '../../secret.png',
        'file:///private/photo.png',
        'https://example.com/photo.png',
        'media:../escape',
        'assets/meme_backgrounds/../../photo.webp'
      ]) {
        final invalid = _clone(original);
        invalid['background']['assetRef'] = path;
        expect(() => MemeDocument.fromJson(invalid), throwsFormatException,
            reason: path);
      }
      final noRef = _clone(original);
      noRef['layers'][0]['type'] = 'image';
      expect(() => MemeDocument.fromJson(noRef), throwsFormatException);
      final coordinates = _clone(original);
      coordinates['weatherSnapshot'] = {
        'nested': [
          {'latitude': 52}
        ]
      };
      expect(() => MemeDocument.fromJson(coordinates), throwsFormatException);
      for (final fields in [
        {'unknownMetadata': 'a path'},
        {'humidity': 101},
        {'wind': -1},
        {'temperature': 'warm'},
        {'stale': 'no'},
        {
          'tags': [4]
        },
      ]) {
        expect(
            () =>
                MemeDocument.fromJson({...original, 'weatherSnapshot': fields}),
            throwsFormatException);
      }
      final unknown = MemeDocument.fromJson(original).copyWith(
          background: const MemeBackground(assetRef: 'media:missing'));
      expect(unknown.missingAssets(catalog.assetPaths), ['media:missing']);
    });
  });

  group('logical history and transforms', () {
    late MemeEditorController editor;
    setUp(() => editor =
        MemeEditorController(catalog.templates.first.createDocument()));
    tearDown(() => editor.dispose());

    test('typing bursts and completed gestures undo as single operations', () {
      final original = editor.document.layers.first;
      for (var i = 0; i < 12; i++) {
        editor.updateLayer(original.copyWith(text: 'Typed $i'),
            coalesceKey: 'text:${original.id}');
      }
      expect(editor.undoCount, 1);
      editor.undo();
      expect(editor.document.layers.first.text, original.text);
      editor.redo();
      expect(editor.document.layers.first.text, 'Typed 11');
      editor.beginGesture();
      for (var i = 0; i < 12; i++) {
        editor.updateLayer(
            editor.document.layers.first.copyWith(x: .01 + i * .001));
      }
      editor.endGesture();
      expect(editor.undoCount, 2);
      editor.undo();
      expect(editor.document.layers.first.x, original.x);
      editor.redo();
      expect(editor.document.layers.first.x, closeTo(.021, .00001));
    });

    test('history retains 100 operations and media referenced by undo and redo',
        () {
      editor.addLayer(const MemeLayer(
          id: 'photo', type: MemeLayerType.image, assetRef: 'media:photo'));
      editor.deleteLayer('photo');
      expect(editor.document.mediaIds, isEmpty);
      expect(editor.mediaIds, {'photo'});
      editor.undo();
      expect(editor.document.mediaIds, {'photo'});
      for (var i = 0; i < 110; i++) {
        editor.apply(editor.document.copyWith(name: 'Revision $i'));
      }
      expect(editor.undoCount, 100);
      for (var i = 0; i < 60; i++) {
        editor.undo();
      }
      expect(editor.document.name, 'Revision 49');
      expect(editor.canRedo, isTrue);
      editor.apply(editor.document.copyWith(name: 'New branch'));
      expect(editor.canRedo, isFalse);
    });

    test('layout changes fit artwork, reflow captions and remain undoable', () {
      final original = editor.document;
      for (final layout in [
        MemeLayout.portrait,
        MemeLayout.story,
        MemeLayout.twoPanel,
        MemeLayout.square
      ]) {
        editor.setLayout(layout);
        expect(editor.document.layout, layout);
        expect(editor.document.background.fit, 'contain');
        for (final layer in editor.document.layers) {
          expect(layer.x + layer.width, lessThanOrEqualTo(1));
          expect(layer.y + layer.height, lessThanOrEqualTo(1));
        }
        if (layout == MemeLayout.twoPanel) {
          expect(editor.document.layers.first.width, .45);
          expect(editor.document.layers[1].x, .525);
          expect(editor.document.layers[1].y, .06);
        }
      }
      for (var i = 0; i < 4; i++) {
        editor.undo();
      }
      expect(editor.document.layout, original.layout);
      expect(editor.document.layers.map((layer) => layer.toJson()),
          original.layers.map((layer) => layer.toJson()));
    });

    test(
        'lock, visibility, duplicate, order, captions and visual style respect layer identity',
        () {
      final original = editor.document.layers.first;
      editor.updateLayer(original.copyWith(locked: true));
      editor.updateLayer(original.copyWith(locked: true, x: .1));
      expect(editor.document.layers.first.x, original.x);
      editor.deleteLayer(original.id);
      expect(editor.document.layers.length, 2);
      editor.updateLayer(original.copyWith(locked: true, hidden: true));
      expect(editor.document.layers.first.hidden, isTrue);
      editor.duplicateLayer(original.id);
      expect(editor.document.layers.length, 3);
      expect(editor.document.layers.last.locked, isFalse);
      expect(editor.selectedLayerId, editor.document.layers.last.id);
      final duplicate = editor.document.layers.last;
      editor.reorderLayer(duplicate.id, 0);
      expect(editor.document.layers.first.id, duplicate.id);
      editor.undo();
      editor.setVisualStyle('retro');
      expect(editor.document.visualStyle, 'retro');
      expect(editor.document.layers.last.textStyle.fontFamily, 'MemeMono');
      expect(editor.document.layers.first.textStyle.fontFamily, 'MemeSans');
      final beforeBlocked = editor.document.toJson();
      expect(() => editor.setCaptions(catalog.templates.first.captionPairs[1]),
          throwsStateError);
      expect(editor.document.toJson(), beforeBlocked);
      expect(editor.document.layers.first.text, original.text);
      expect(editor.document.layers[1].text,
          catalog.templates.first.defaultCaption.bottom);
      expect(editor.document.layers.last.id, duplicate.id);
      editor.updateLayer(editor.document.layers.first.copyWith(locked: false));
      editor.setCaptions(catalog.templates.first.captionPairs[1]);
      expect(editor.document.layers.first.text,
          catalog.templates.first.captionPairs[1].top);
      expect(editor.document.layers[1].text,
          catalog.templates.first.captionPairs[1].bottom);
    });

    test(
        'save completion for an older snapshot does not mark a newer edit saved',
        () {
      editor.apply(editor.document.copyWith(name: 'Saving this'));
      final saved = editor.document;
      editor.apply(editor.document.copyWith(name: 'Typed while saving'));
      editor.markSaved(document: saved);
      expect(editor.isDirty, isTrue);
      editor.undo();
      expect(editor.isDirty, isFalse);
      editor.redo();
      editor.markSaved();
      expect(editor.isDirty, isFalse);
      expect(editor.hasUserEdits, isTrue);
    });

    test('caption roles survive reorder, duplication and deleting one caption',
        () {
      final top = editor.document.layers[0];
      final bottom = editor.document.layers[1];
      editor.duplicateLayer(top.id);
      final duplicate = editor.document.layers.last;
      expect(duplicate.role, isNull);
      editor.reorderLayer(duplicate.id, 0);
      editor.reorderLayer(bottom.id, 1);
      editor.setCaptions(catalog.templates.first.captionPairs[1]);
      expect(editor.document.layers.first.text, top.text);
      expect(editor.document.layers.first.role, isNull);
      expect(
          editor.document.layers
              .firstWhere((layer) => layer.role == 'top')
              .text,
          catalog.templates.first.captionPairs[1].top);
      expect(
          editor.document.layers
              .firstWhere((layer) => layer.role == 'bottom')
              .text,
          catalog.templates.first.captionPairs[1].bottom);
      editor.deleteLayer(top.id);
      editor.setCaptions(catalog.templates.first.captionPairs[2]);
      expect(
          editor.document.layers
              .firstWhere((layer) => layer.role == 'top')
              .text,
          catalog.templates.first.captionPairs[2].top);
      expect(
          editor.document.layers
              .firstWhere((layer) => layer.role == 'bottom')
              .id,
          bottom.id);
      expect(editor.document.layers.first.text, top.text);
      editor.deleteLayer(
          editor.document.layers.firstWhere((layer) => layer.role == 'top').id);
      editor.deleteLayer(bottom.id);
      editor.setCaptions(catalog.templates.first.captionPairs[3]);
      expect(editor.document.layers.first.text, top.text);
      expect(editor.document.layers.where((layer) => layer.role != null).length,
          2);
    });
  });
}

Map<String, dynamic> _clone(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
