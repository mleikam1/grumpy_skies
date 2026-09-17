import 'dart:convert';
import 'dart:math';

/// The persisted editor format is independent of viewport size and image bytes.
enum MemeLayerType { text, sticker, image, shape, weatherBadge }

enum MemeLayout {
  square,
  portrait,
  story,
  twoPanel;

  int get pixelWidth => 1080;
  int get pixelHeight => switch (this) {
        portrait => 1350,
        story => 1920,
        _ => 1080,
      };
  double get aspectRatio => pixelWidth / pixelHeight;
  String get label => switch (this) {
        square => 'Square · 1:1',
        portrait => 'Portrait · 4:5',
        story => 'Story · 9:16',
        twoPanel => 'Two panels · 1:1',
      };
}

final _random = Random.secure();
int _idCounter = 0;
String newMemeId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${(_idCounter++).toRadixString(36)}_${_random.nextInt(0x7fffffff).toRadixString(36)}';

const _unset = Object();

/// All sizes, including stroke and font size, are fractions of canvas width.
class MemeTextStyle {
  const MemeTextStyle({
    this.fontFamily = 'MemeSans',
    this.fontSize = .049,
    this.color = 0xff172c42,
    this.strokeColor = 0xffffffff,
    this.strokeWidth = 0,
    this.shadow = false,
    this.pillColor,
    this.alignment = 'center',
    this.uppercase = false,
    this.lineHeight = 1.08,
    this.fontWeight = 900,
  });

  final String fontFamily;
  final double fontSize;
  final int color, strokeColor;
  final double strokeWidth;
  final bool shadow;
  final int? pillColor;
  final String alignment;
  final bool uppercase;
  final double lineHeight;
  final int fontWeight;

  MemeTextStyle copyWith({
    String? fontFamily,
    double? fontSize,
    int? color,
    int? strokeColor,
    double? strokeWidth,
    bool? shadow,
    Object? pillColor = _unset,
    String? alignment,
    bool? uppercase,
    double? lineHeight,
    int? fontWeight,
  }) =>
      MemeTextStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        shadow: shadow ?? this.shadow,
        pillColor:
            identical(pillColor, _unset) ? this.pillColor : pillColor as int?,
        alignment: alignment ?? this.alignment,
        uppercase: uppercase ?? this.uppercase,
        lineHeight: lineHeight ?? this.lineHeight,
        fontWeight: fontWeight ?? this.fontWeight,
      );

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': color,
        'strokeColor': strokeColor,
        'strokeWidth': strokeWidth,
        'shadow': shadow,
        'pillColor': pillColor,
        'alignment': alignment,
        'uppercase': uppercase,
        'lineHeight': lineHeight,
        'fontWeight': fontWeight,
      };

  factory MemeTextStyle.fromJson(Map<String, dynamic> json) {
    final alignment = _string(json, 'alignment', fallback: 'center');
    if (!{'left', 'center', 'right'}.contains(alignment)) {
      throw const FormatException('Unsupported text alignment.');
    }
    final font = _string(json, 'fontFamily', fallback: 'MemeSans');
    if (!{'MemeSans', 'MemeMono'}.contains(font)) {
      throw const FormatException('Unsupported bundled font.');
    }
    final weight =
        _integer(json, 'fontWeight', fallback: 900, min: 100, max: 900);
    if (weight % 100 != 0) throw const FormatException('Invalid font weight.');
    return MemeTextStyle(
      fontFamily: font,
      fontSize: _number(json, 'fontSize', fallback: .049, min: .008, max: .4),
      color: _color(json, 'color', 0xff172c42),
      strokeColor: _color(json, 'strokeColor', 0xffffffff),
      strokeWidth: _number(json, 'strokeWidth', fallback: 0, min: 0, max: .02),
      shadow: _boolean(json, 'shadow'),
      pillColor:
          json['pillColor'] == null ? null : _color(json, 'pillColor', 0),
      alignment: alignment,
      uppercase: _boolean(json, 'uppercase'),
      lineHeight: _number(json, 'lineHeight', fallback: 1.08, min: .8, max: 3),
      fontWeight: weight,
    );
  }
}

class MemeLayer {
  const MemeLayer({
    required this.id,
    required this.type,
    this.x = .1,
    this.y = .1,
    this.width = .8,
    this.height = .18,
    this.rotation = 0,
    this.locked = false,
    this.hidden = false,
    this.assetRef,
    this.role,
    this.text = '',
    this.textStyle = const MemeTextStyle(),
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.flipX = false,
    this.flipY = false,
    this.brightness = 0,
    this.contrast = 1,
    this.color = 0xffffd65c,
    this.shape = 'rectangle',
  });

  final String id;
  final MemeLayerType type;
  final double x, y, width, height, rotation;
  final bool locked, hidden;
  final String? assetRef;
  final String? role;
  final String text;
  final MemeTextStyle textStyle;
  final double zoom, panX, panY;
  final bool flipX, flipY;
  final double brightness, contrast;
  final int color;
  final String shape;

  MemeLayer copyWith({
    String? id,
    MemeLayerType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? locked,
    bool? hidden,
    Object? assetRef = _unset,
    Object? role = _unset,
    String? text,
    MemeTextStyle? textStyle,
    double? zoom,
    double? panX,
    double? panY,
    bool? flipX,
    bool? flipY,
    double? brightness,
    double? contrast,
    int? color,
    String? shape,
  }) =>
      MemeLayer(
        id: id ?? this.id,
        type: type ?? this.type,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
        assetRef:
            identical(assetRef, _unset) ? this.assetRef : assetRef as String?,
        role: identical(role, _unset) ? this.role : role as String?,
        text: text ?? this.text,
        textStyle: textStyle ?? this.textStyle,
        zoom: zoom ?? this.zoom,
        panX: panX ?? this.panX,
        panY: panY ?? this.panY,
        flipX: flipX ?? this.flipX,
        flipY: flipY ?? this.flipY,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        color: color ?? this.color,
        shape: shape ?? this.shape,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'locked': locked,
        'hidden': hidden,
        'assetRef': assetRef,
        'role': role,
        'text': text,
        'textStyle': textStyle.toJson(),
        'zoom': zoom,
        'panX': panX,
        'panY': panY,
        'flipX': flipX,
        'flipY': flipY,
        'brightness': brightness,
        'contrast': contrast,
        'color': color,
        'shape': shape,
      };

  factory MemeLayer.fromJson(Map<String, dynamic> json) {
    final type = _enumValue(MemeLayerType.values, json['type'], 'layer type');
    final x = _number(json, 'x', min: 0, max: 1);
    final y = _number(json, 'y', min: 0, max: 1);
    final width = _number(json, 'width', min: .01, max: 1);
    final height = _number(json, 'height', min: .01, max: 1);
    if (x + width > 1.000001 || y + height > 1.000001) {
      throw const FormatException('A layer extends beyond the canvas.');
    }
    final shape = _string(json, 'shape', fallback: 'rectangle');
    if (!{'rectangle', 'ellipse', 'line'}.contains(shape)) {
      throw const FormatException('Unsupported shape.');
    }
    final assetRef = validateMemeAssetRef(json['assetRef']);
    final role = json['role'];
    if (role != null && role != 'top' && role != 'bottom') {
      throw const FormatException('Unknown caption role.');
    }
    if ((type == MemeLayerType.image || type == MemeLayerType.sticker) &&
        assetRef == null) {
      throw const FormatException('An image layer has no asset reference.');
    }
    return MemeLayer(
      id: _id(json, 'id'),
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation:
          _number(json, 'rotation', fallback: 0, min: -pi * 2, max: pi * 2),
      locked: _boolean(json, 'locked'),
      hidden: _boolean(json, 'hidden'),
      assetRef: assetRef,
      role: role as String?,
      text: _string(json, 'text', fallback: '', max: 4000),
      textStyle: MemeTextStyle.fromJson(_map(json['textStyle'] ?? {})),
      zoom: _number(json, 'zoom', fallback: 1, min: 1, max: 8),
      panX: _number(json, 'panX', fallback: 0, min: -1, max: 1),
      panY: _number(json, 'panY', fallback: 0, min: -1, max: 1),
      flipX: _boolean(json, 'flipX'),
      flipY: _boolean(json, 'flipY'),
      brightness: _number(json, 'brightness', fallback: 0, min: -1, max: 1),
      contrast: _number(json, 'contrast', fallback: 1, min: 0, max: 3),
      color: _color(json, 'color', 0xffffd65c),
      shape: shape,
    );
  }
}

class MemeBackground {
  const MemeBackground({
    this.assetRef,
    this.color = 0xfffff9ed,
    this.fit = 'contain',
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
    this.brightness = 0,
    this.contrast = 1,
  });
  final String? assetRef;
  final int color;
  final String fit;
  final double zoom, panX, panY, rotation;
  final bool flipX, flipY;
  final double brightness, contrast;

  MemeBackground copyWith({
    Object? assetRef = _unset,
    int? color,
    String? fit,
    double? zoom,
    double? panX,
    double? panY,
    double? rotation,
    bool? flipX,
    bool? flipY,
    double? brightness,
    double? contrast,
  }) =>
      MemeBackground(
        assetRef:
            identical(assetRef, _unset) ? this.assetRef : assetRef as String?,
        color: color ?? this.color,
        fit: fit ?? this.fit,
        zoom: zoom ?? this.zoom,
        panX: panX ?? this.panX,
        panY: panY ?? this.panY,
        rotation: rotation ?? this.rotation,
        flipX: flipX ?? this.flipX,
        flipY: flipY ?? this.flipY,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
      );

  Map<String, dynamic> toJson() => {
        'assetRef': assetRef,
        'color': color,
        'fit': fit,
        'zoom': zoom,
        'panX': panX,
        'panY': panY,
        'rotation': rotation,
        'flipX': flipX,
        'flipY': flipY,
        'brightness': brightness,
        'contrast': contrast,
      };

  factory MemeBackground.fromJson(Map<String, dynamic> json) {
    final fit = _string(json, 'fit', fallback: 'contain');
    if (!{'contain', 'cover'}.contains(fit)) {
      throw const FormatException('Unsupported background fit.');
    }
    return MemeBackground(
      assetRef: validateMemeAssetRef(json['assetRef']),
      color: _color(json, 'color', 0xfffff9ed),
      fit: fit,
      zoom: _number(json, 'zoom', fallback: 1, min: 1, max: 8),
      panX: _number(json, 'panX', fallback: 0, min: -1, max: 1),
      panY: _number(json, 'panY', fallback: 0, min: -1, max: 1),
      rotation:
          _number(json, 'rotation', fallback: 0, min: -pi * 2, max: pi * 2),
      flipX: _boolean(json, 'flipX'),
      flipY: _boolean(json, 'flipY'),
      brightness: _number(json, 'brightness', fallback: 0, min: -1, max: 1),
      contrast: _number(json, 'contrast', fallback: 1, min: 0, max: 3),
    );
  }
}

class MemeDocument {
  MemeDocument({
    required this.id,
    required this.name,
    this.templateId,
    this.layout = MemeLayout.square,
    this.background = const MemeBackground(),
    List<MemeLayer> layers = const [],
    Map<String, dynamic>? weatherSnapshot,
    this.personaId,
    this.captionId,
    this.visualStyle = 'cute',
    this.watermark = true,
    required this.createdAt,
    required this.updatedAt,
  })  : layers = List.unmodifiable(layers),
        weatherSnapshot =
            weatherSnapshot == null ? null : _freezeMap(weatherSnapshot);

  static const schemaVersion = 2;
  final String id, name;
  final String? templateId, personaId, captionId;
  final MemeLayout layout;
  final MemeBackground background;
  final List<MemeLayer> layers;
  final Map<String, dynamic>? weatherSnapshot;
  final String visualStyle;
  final bool watermark;
  final DateTime createdAt, updatedAt;

  int get pixelWidth => layout.pixelWidth;
  int get pixelHeight => layout.pixelHeight;
  double get aspectRatio => layout.aspectRatio;
  Map<String, dynamic>? get weather => weatherSnapshot;
  Set<String> get assetRefs => {
        if (background.assetRef != null) background.assetRef!,
        for (final layer in layers)
          if (layer.assetRef != null) layer.assetRef!,
      };
  Set<String> get mediaIds => assetRefs
      .where((ref) => ref.startsWith('media:'))
      .map((ref) => ref.substring(6))
      .toSet();

  factory MemeDocument.blank({String name = 'Untitled weather masterpiece'}) {
    final now = DateTime.now().toUtc();
    return MemeDocument(
      id: newMemeId(),
      name: name,
      createdAt: now,
      updatedAt: now,
      layers: [
        MemeLayer(
            id: newMemeId(),
            type: MemeLayerType.text,
            y: .04,
            role: 'top',
            text: 'THE WEATHER HAS JOKES'),
        MemeLayer(
            id: newMemeId(),
            type: MemeLayerType.text,
            y: .76,
            role: 'bottom',
            text: 'YOUR PUNCHLINE GOES HERE.'),
      ],
    );
  }

  MemeDocument copyWith({
    String? id,
    String? name,
    Object? templateId = _unset,
    MemeLayout? layout,
    MemeBackground? background,
    List<MemeLayer>? layers,
    Object? weatherSnapshot = _unset,
    Object? personaId = _unset,
    Object? captionId = _unset,
    String? visualStyle,
    bool? watermark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MemeDocument(
        id: id ?? this.id,
        name: name ?? this.name,
        templateId: identical(templateId, _unset)
            ? this.templateId
            : templateId as String?,
        layout: layout ?? this.layout,
        background: background ?? this.background,
        layers: layers ?? this.layers,
        weatherSnapshot: identical(weatherSnapshot, _unset)
            ? this.weatherSnapshot
            : weatherSnapshot as Map<String, dynamic>?,
        personaId: identical(personaId, _unset)
            ? this.personaId
            : personaId as String?,
        captionId: identical(captionId, _unset)
            ? this.captionId
            : captionId as String?,
        visualStyle: visualStyle ?? this.visualStyle,
        watermark: watermark ?? this.watermark,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'templateId': templateId,
        'layout': layout.name,
        'background': background.toJson(),
        'layers': layers.map((layer) => layer.toJson()).toList(),
        'weatherSnapshot': weatherSnapshot,
        'personaId': personaId,
        'captionId': captionId,
        'visualStyle': visualStyle,
        'watermark': watermark,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory MemeDocument.fromJson(Map<String, dynamic> source) {
    final json = Map<String, dynamic>.from(source);
    final version = json['schemaVersion'];
    if (version != 1 && version != schemaVersion) {
      throw const FormatException(
          'This project version is not supported. Keep the original file.');
    }
    // Version 1 used `weather` and did not include visual/photo adjustments.
    if (version == 1) {
      json['weatherSnapshot'] ??= json.remove('weather');
      if (json['background'] is String) {
        json['background'] = {'assetRef': json['background']};
      }
    }
    final rawLayers = json['layers'];
    if (rawLayers is! List || rawLayers.length > 100) {
      throw const FormatException('A project must contain at most 100 layers.');
    }
    final layers =
        rawLayers.map((value) => MemeLayer.fromJson(_map(value))).toList();
    if (version == 1 && !layers.any((layer) => layer.role != null)) {
      var caption = 0;
      for (var i = 0; i < layers.length && caption < 2; i++) {
        if (layers[i].type == MemeLayerType.text) {
          layers[i] =
              layers[i].copyWith(role: caption++ == 0 ? 'top' : 'bottom');
        }
      }
    }
    if (layers.map((layer) => layer.id).toSet().length != layers.length) {
      throw const FormatException('Duplicate layer IDs.');
    }
    final roles =
        layers.map((layer) => layer.role).whereType<String>().toList();
    if (roles.toSet().length != roles.length ||
        layers.any((layer) =>
            layer.role != null && layer.type != MemeLayerType.text)) {
      throw const FormatException(
          'Caption roles must identify unique text layers.');
    }
    final style = _string(json, 'visualStyle', fallback: 'cute');
    if (!{'epic', 'cute', 'sarcastic', 'cozy', 'retro'}.contains(style)) {
      throw const FormatException('Unsupported visual style.');
    }
    final createdAt = _date(json, 'createdAt');
    final updatedAt = _date(json, 'updatedAt');
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException(
          'A project modification date predates its creation.');
    }
    final weather =
        json['weatherSnapshot'] == null ? null : _map(json['weatherSnapshot']);
    if (weather != null) {
      if (jsonEncode(weather).length > 16000) {
        throw const FormatException('Weather snapshot is too large.');
      }
      if (_containsLocationCoordinates(weather)) {
        throw const FormatException(
            'Precise coordinates must not be stored in meme projects.');
      }
    }
    if (weather != null) _validateWeather(weather);
    return MemeDocument(
      id: _id(json, 'id'),
      name: _string(json, 'name', max: 160),
      templateId: json['templateId'] == null ? null : _id(json, 'templateId'),
      layout: _enumValue(MemeLayout.values, json['layout'], 'canvas layout'),
      background: MemeBackground.fromJson(_map(json['background'])),
      layers: layers,
      weatherSnapshot: weather,
      personaId: json['personaId'] == null ? null : _id(json, 'personaId'),
      captionId: json['captionId'] == null ? null : _id(json, 'captionId'),
      visualStyle: style,
      watermark: _boolean(json, 'watermark', fallback: true),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Asset existence is checked after parsing against the catalog and media store.
  List<String> missingAssets(Set<String> availableRefs) =>
      assetRefs.where((ref) => !availableRefs.contains(ref)).toList();
}

String? validateMemeAssetRef(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 240) {
    throw const FormatException('Invalid asset reference.');
  }
  if (RegExp(r'^media:[a-zA-Z0-9_-]{1,160}$').hasMatch(value) ||
      RegExp(r'^assets/meme_(backgrounds|thumbnails|stickers)/[a-z0-9_]+\.(webp|png)$')
          .hasMatch(value)) {
    return value;
  }
  throw const FormatException(
      'Only bundled artwork and local media IDs are permitted.');
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key,
    {String? fallback, int max = 240}) {
  final value = json[key] ?? fallback;
  if (value is! String || value.length > max) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

String _id(Map<String, dynamic> json, String key) {
  final value = _string(json, key, max: 160);
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(value)) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

double _number(Map<String, dynamic> json, String key,
    {double? fallback, required double min, required double max}) {
  final value = json[key] ?? fallback;
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw FormatException('Invalid $key.');
  }
  return value.toDouble();
}

int _integer(Map<String, dynamic> json, String key,
    {int? fallback, required int min, required int max}) {
  final value = json[key] ?? fallback;
  if (value is! int || value < min || value > max) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

int _color(Map<String, dynamic> json, String key, int fallback) =>
    _integer(json, key, fallback: fallback, min: 0, max: 0xffffffff);

bool _boolean(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key] ?? fallback;
  if (value is! bool) throw FormatException('Invalid $key.');
  return value;
}

T _enumValue<T extends Enum>(List<T> values, Object? value, String label) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException('Unsupported $label.');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null) throw FormatException('Invalid $key.');
  return value.toUtc();
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.unmodifiable(
        source.map((key, value) => MapEntry(key, _freeze(value))));

Object? _freeze(Object? value) {
  if (value is Map<String, dynamic>) return _freezeMap(value);
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const FormatException('Snapshot values must be JSON compatible.');
}

bool _containsLocationCoordinates(Map<String, dynamic> map) =>
    map.entries.any((entry) {
      if ({'lat', 'lon', 'lng', 'latitude', 'longitude', 'coordinates'}
          .contains(entry.key.toLowerCase())) {
        return true;
      }
      return _hasCoordinates(entry.value);
    });

bool _hasCoordinates(Object? value) {
  if (value is Map<String, dynamic>) return _containsLocationCoordinates(value);
  if (value is List) return value.any(_hasCoordinates);
  return false;
}

void _validateWeather(Map<String, dynamic> weather) {
  const allowed = {
    'schemaVersion',
    'source',
    'observedAt',
    'frozenAt',
    'stale',
    'timezone',
    'timezoneOffsetSeconds',
    'temperatureUnit',
    'windUnit',
    'temperature',
    'feelsLike',
    'condition',
    'humidity',
    'wind',
    'day',
    'city',
    'tags',
    'attribution'
  };
  if (weather.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unexpected weather metadata.');
  }
  if (weather.containsKey('schemaVersion') && weather['schemaVersion'] != 1) {
    throw const FormatException('Unsupported weather snapshot version.');
  }
  for (final key in ['observedAt', 'frozenAt']) {
    if (weather.containsKey(key)) _date(weather, key);
  }
  for (final key in ['temperature', 'feelsLike']) {
    if (weather.containsKey(key)) _number(weather, key, min: -300, max: 300);
  }
  if (weather.containsKey('humidity')) {
    _number(weather, 'humidity', min: 0, max: 100);
  }
  if (weather.containsKey('wind')) _number(weather, 'wind', min: 0, max: 1000);
  if (weather.containsKey('timezoneOffsetSeconds')) {
    _integer(weather, 'timezoneOffsetSeconds', min: -64800, max: 64800);
  }
  if (weather.containsKey('stale')) _boolean(weather, 'stale');
  for (final key in ['timezone', 'condition', 'day', 'city', 'attribution']) {
    if (weather.containsKey(key)) _string(weather, key, max: 500);
  }
  for (final entry in {
    'source': {'cached', 'sample', 'custom'},
    'temperatureUnit': {'celsius', 'fahrenheit'},
    'windUnit': {'mph', 'kph'}
  }.entries) {
    if (weather.containsKey(entry.key) &&
        !entry.value.contains(weather[entry.key])) {
      throw FormatException('Invalid weather ${entry.key}.');
    }
  }
  if (weather.containsKey('tags')) {
    final tags = weather['tags'];
    if (tags is! List ||
        tags.length > 30 ||
        tags.any((tag) => tag is! String || tag.length > 80)) {
      throw const FormatException('Invalid weather tags.');
    }
  }
}
