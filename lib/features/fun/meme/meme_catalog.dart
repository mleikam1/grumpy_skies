import 'dart:convert';

import 'package:flutter/services.dart';

import '../../roasts/models/roast_persona.dart';
import 'models/meme_document.dart';

class MemeCaptionPair {
  MemeCaptionPair({
    required this.id,
    required this.top,
    required this.bottom,
    this.personaId,
    List<String> tags = const [],
  }) : tags = List.unmodifiable(tags);

  final String id, top, bottom;
  final String? personaId;
  final List<String> tags;

  factory MemeCaptionPair.fromJson(Map<String, dynamic> json) {
    final seed = json['seedPersonaId'] ?? json['persona'];
    final personaId = seed == null || seed == 'neutral'
        ? null
        : RoastPersonas.normalizeIdOrNull(seed as String);
    if (seed != null && seed != 'neutral' && personaId == null) {
      throw FormatException('Unknown catalog persona: $seed');
    }
    return MemeCaptionPair(
      id: _id(json, 'id'),
      top: _string(json, 'top', max: 1000),
      bottom: _string(json, 'bottom', max: 1000),
      personaId: personaId,
      tags: _strings(json['tags']),
    );
  }
}

class MemeSafeTextZone {
  const MemeSafeTextZone({
    required this.role,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final String role;
  final double x, y, width, height;

  factory MemeSafeTextZone.fromJson(Map<String, dynamic> json) {
    final role = _string(json, 'role');
    if (!{'top', 'bottom'}.contains(role)) {
      throw const FormatException('Unsupported caption role.');
    }
    final zone = MemeSafeTextZone(
      role: role,
      x: _unit(json['x']),
      y: _unit(json['y']),
      width: _unit(json['width']),
      height: _unit(json['height']),
    );
    if (zone.width <= 0 ||
        zone.height <= 0 ||
        zone.x + zone.width > 1 ||
        zone.y + zone.height > 1) {
      throw const FormatException('Invalid safe text rectangle.');
    }
    return zone;
  }
}

class MemeTemplate {
  MemeTemplate({
    required this.id,
    required this.name,
    required this.description,
    required List<String> tags,
    required this.assetPath,
    required this.thumbnailPath,
    required List<MemeSafeTextZone> safeTextZones,
    required List<MemeCaptionPair> captionPairs,
    required this.defaultCaptionId,
    this.focalX = .5,
    this.focalY = .5,
    this.autoSuggestRequiresVerifiedSignal = false,
    this.defaultTextStyle = const MemeTextStyle(),
  })  : tags = List.unmodifiable(tags),
        safeTextZones = List.unmodifiable(safeTextZones),
        captionPairs = List.unmodifiable(captionPairs);

  final String id,
      name,
      description,
      assetPath,
      thumbnailPath,
      defaultCaptionId;
  final List<String> tags;
  final List<MemeSafeTextZone> safeTextZones;
  final List<MemeCaptionPair> captionPairs;
  final double focalX, focalY;
  final bool autoSuggestRequiresVerifiedSignal;
  final MemeTextStyle defaultTextStyle;

  MemeCaptionPair get defaultCaption =>
      captionPairs.firstWhere((caption) => caption.id == defaultCaptionId);

  MemeDocument createDocument({
    MemeCaptionPair? caption,
    String? personaId,
    Map<String, dynamic>? weatherSnapshot,
  }) {
    final selected = caption ?? defaultCaption;
    final now = DateTime.now().toUtc();
    return MemeDocument(
      id: newMemeId(),
      name: name,
      templateId: id,
      background: MemeBackground(assetRef: assetPath),
      layers: [
        for (final zone in safeTextZones)
          MemeLayer(
            id: newMemeId(),
            type: MemeLayerType.text,
            role: zone.role,
            x: zone.x,
            y: zone.y,
            width: zone.width,
            height: zone.height,
            text: zone.role == 'top' ? selected.top : selected.bottom,
            textStyle: defaultTextStyle,
          ),
      ],
      weatherSnapshot: weatherSnapshot,
      personaId: personaId ?? selected.personaId,
      captionId: selected.id,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MemeTemplate.fromJson(Map<String, dynamic> json) {
    final rawStyle = _map(json['defaultTextStyle']);
    final style = MemeTextStyle.fromJson({
      'fontFamily': 'MemeSans',
      'fontSize': rawStyle['fontSizeNormalized'],
      'fontWeight': rawStyle['fontWeight'],
      'color': _hexColor(rawStyle['fill']),
      'strokeWidth': rawStyle['strokeWidthNormalized'],
      'alignment': rawStyle['alignment'],
      'uppercase': rawStyle['forceUppercase'],
    });
    final captions =
        _objects(json['captionPairs']).map(MemeCaptionPair.fromJson).toList();
    final zones =
        _objects(json['safeTextZones']).map(MemeSafeTextZone.fromJson).toList();
    final defaultId = _id(json, 'defaultCaptionId');
    if (captions.isEmpty ||
        !captions.any((caption) => caption.id == defaultId)) {
      throw const FormatException('Default caption is missing.');
    }
    if (zones.length != 2 ||
        zones.map((zone) => zone.role).toSet().length != 2) {
      throw const FormatException(
          'Each template needs top and bottom safe text zones.');
    }
    final focal = _map(json['focalPoint']);
    if (json['width'] != 1080 || json['height'] != 1080) {
      throw const FormatException('Starter artwork must be 1080×1080.');
    }
    return MemeTemplate(
      id: _id(json, 'id'),
      name: _string(json, 'name'),
      description: _string(json, 'description', max: 1000),
      tags: _strings(json['tags']),
      assetPath: validateMemeAssetRef(json['assetPath']) ??
          (throw const FormatException('Missing background.')),
      thumbnailPath: validateMemeAssetRef(json['thumbnailPath']) ??
          (throw const FormatException('Missing thumbnail.')),
      safeTextZones: zones,
      captionPairs: captions,
      defaultCaptionId: defaultId,
      focalX: _unit(focal['x']),
      focalY: _unit(focal['y']),
      autoSuggestRequiresVerifiedSignal:
          json['autoSuggestRequiresVerifiedSignal'] == true,
      defaultTextStyle: style,
    );
  }
}

class MemeSticker {
  const MemeSticker(
      {required this.id, required this.name, required this.assetPath});
  final String id, name, assetPath;

  factory MemeSticker.fromJson(Map<String, dynamic> json) {
    if (json['width'] != 512 || json['height'] != 512) {
      throw const FormatException('Starter stickers must be 512×512.');
    }
    return MemeSticker(
      id: _id(json, 'id'),
      name: _string(json, 'name'),
      assetPath: validateMemeAssetRef(json['assetPath']) ??
          (throw const FormatException('Missing sticker.')),
    );
  }
}

class MemeCatalog {
  MemeCatalog({
    required List<MemeTemplate> templates,
    required List<MemeSticker> stickers,
    required List<MemeCaptionPair> personaCaptions,
  })  : templates = List.unmodifiable(templates),
        stickers = List.unmodifiable(stickers),
        personaCaptions = List.unmodifiable(personaCaptions);

  static const catalogAsset =
      'assets/meme_content/weather_meme_catalog.v1.json';
  static const stickersAsset = 'assets/meme_content/weather_stickers.v1.json';

  final List<MemeTemplate> templates;
  final List<MemeSticker> stickers;
  final List<MemeCaptionPair> personaCaptions;

  Iterable<MemeCaptionPair> get allCaptions => [
        for (final template in templates) ...template.captionPairs,
        ...personaCaptions,
      ];
  Set<String> get assetPaths => {
        for (final template in templates) ...[
          template.assetPath,
          template.thumbnailPath
        ],
        for (final sticker in stickers) sticker.assetPath,
      };
  Set<String> get tags => templates.expand((template) => template.tags).toSet();

  MemeTemplate? templateById(String id) {
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  static Future<MemeCatalog> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final data = await Future.wait([
      assets.loadString(catalogAsset),
      assets.loadString(stickersAsset),
    ]);
    return MemeCatalog.fromJson(
        _map(jsonDecode(data[0])), _map(jsonDecode(data[1])));
  }

  factory MemeCatalog.fromJson(
      Map<String, dynamic> catalog, Map<String, dynamic> stickers) {
    if (catalog['schemaVersion'] != 1 || stickers['schemaVersion'] != 1) {
      throw const FormatException('Unsupported starter catalog version.');
    }
    final result = MemeCatalog(
      templates:
          _objects(catalog['templates']).map(MemeTemplate.fromJson).toList(),
      stickers:
          _objects(stickers['stickers']).map(MemeSticker.fromJson).toList(),
      personaCaptions: _objects(catalog['personaCaptions'])
          .map(MemeCaptionPair.fromJson)
          .toList(),
    );
    _unique(result.templates.map((template) => template.id), 'template');
    _unique(result.stickers.map((sticker) => sticker.id), 'sticker');
    _unique(result.allCaptions.map((caption) => caption.id), 'caption');
    if (result.templates.isEmpty || result.stickers.isEmpty) {
      throw const FormatException('The starter catalog is empty.');
    }
    return result;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a catalog object.');
  }
  return value;
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List || value.length > 1000) {
    throw const FormatException('Invalid catalog list.');
  }
  return value.map(_map).toList();
}

List<String> _strings(Object? value) {
  if (value is! List ||
      value.length > 30 ||
      value.any((item) => item is! String || item.length > 80)) {
    throw const FormatException('Invalid catalog tags.');
  }
  return value.cast<String>();
}

String _string(Map<String, dynamic> json, String key, {int max = 240}) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.length > max) {
    throw FormatException('Invalid catalog $key.');
  }
  return value;
}

String _id(Map<String, dynamic> json, String key) {
  final id = _string(json, key, max: 160);
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
    throw FormatException('Invalid catalog $key.');
  }
  return id;
}

double _unit(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException('Invalid normalized catalog coordinate.');
  }
  return value.toDouble();
}

int _hexColor(Object? value) {
  if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw const FormatException('Invalid catalog color.');
  }
  return 0xff000000 | int.parse(value.substring(1), radix: 16);
}

void _unique(Iterable<String> ids, String label) {
  final all = ids.toList();
  if (all.toSet().length != all.length) {
    throw FormatException('Duplicate $label IDs.');
  }
}
