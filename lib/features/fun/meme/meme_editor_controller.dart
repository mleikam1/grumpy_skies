import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'meme_catalog.dart';
import 'models/meme_document.dart';

/// Small immutable document snapshots retain references, never raster bytes.
class MemeEditorController extends ChangeNotifier {
  MemeEditorController(MemeDocument document)
      : _document = document,
        _savedFingerprint = _fingerprint(document),
        _initialFingerprint = _fingerprint(document);

  static const historyLimit = 100;
  MemeDocument _document;
  final List<MemeDocument> _undo = [], _redo = [];
  String? _selectedLayerId;
  String _savedFingerprint, _initialFingerprint;
  String? _coalesceKey;
  DateTime? _lastChange;
  bool _inGesture = false;
  bool _gestureRecorded = false;
  int _revision = 0;

  MemeDocument get document => _document;
  String? get selectedLayerId => _selectedLayerId;
  MemeLayer? get selectedLayer {
    for (final layer in _document.layers) {
      if (layer.id == _selectedLayerId) return layer;
    }
    return null;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => _fingerprint(_document) != _savedFingerprint;
  bool get hasUserEdits => _fingerprint(_document) != _initialFingerprint;
  bool get canReplaceCaptions =>
      !_captionLayers.any((layer) => layer?.locked == true);
  int get revision => _revision;
  int get undoCount => _undo.length;
  Set<String> get mediaIds => {
        ..._document.mediaIds,
        for (final document in _undo) ...document.mediaIds,
        for (final document in _redo) ...document.mediaIds,
      };

  void selectLayer(String? id) {
    if (id != null && !_document.layers.any((layer) => layer.id == id)) return;
    _selectedLayerId = id;
    notifyListeners();
  }

  void apply(MemeDocument next, {String? coalesceKey}) {
    if (next.id != _document.id) {
      throw ArgumentError('Use load to switch to another document.');
    }
    // Fail at the edit boundary so invalid geometry cannot become a saved draft.
    final validated = MemeDocument.fromJson(next.toJson());
    if (_fingerprint(validated) == _fingerprint(_document)) return;
    final now = DateTime.now().toUtc();
    final coalesced = !_inGesture &&
        coalesceKey != null &&
        coalesceKey == _coalesceKey &&
        _lastChange != null &&
        now.difference(_lastChange!).inMilliseconds < 800;
    if ((_inGesture && !_gestureRecorded) || (!_inGesture && !coalesced)) {
      _undo.add(_document);
      if (_undo.length > historyLimit) _undo.removeAt(0);
    }
    if (_inGesture) _gestureRecorded = true;
    _redo.clear();
    _coalesceKey = coalesceKey;
    _lastChange = now;
    _document = validated.copyWith(updatedAt: now);
    _revision++;
    _checkSelection();
    notifyListeners();
  }

  void load(MemeDocument next) {
    _document = MemeDocument.fromJson(next.toJson());
    _undo.clear();
    _redo.clear();
    _selectedLayerId = null;
    _savedFingerprint = _initialFingerprint = _fingerprint(_document);
    _revision++;
    endGesture();
    notifyListeners();
  }

  void markSaved({MemeDocument? document}) {
    if (document != null && document.id != _document.id) return;
    _savedFingerprint = _fingerprint(document ?? _document);
    notifyListeners();
  }

  void beginGesture() {
    _inGesture = true;
    _gestureRecorded = false;
    _coalesceKey = null;
  }

  void endGesture() {
    _inGesture = false;
    _gestureRecorded = false;
    _coalesceKey = null;
    _lastChange = null;
  }

  void undo() {
    if (!canUndo) return;
    endGesture();
    _redo.add(_document);
    _document = _undo.removeLast().copyWith(updatedAt: DateTime.now().toUtc());
    _revision++;
    _checkSelection();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    endGesture();
    _undo.add(_document);
    _document = _redo.removeLast().copyWith(updatedAt: DateTime.now().toUtc());
    _revision++;
    _checkSelection();
    notifyListeners();
  }

  void updateLayer(MemeLayer layer, {String? coalesceKey}) {
    final existing = _find(layer.id);
    if (existing == null) return;
    if (existing.locked) {
      layer = existing.copyWith(locked: layer.locked, hidden: layer.hidden);
    }
    apply(
        _document.copyWith(layers: [
          for (final current in _document.layers)
            current.id == layer.id ? layer : current,
        ]),
        coalesceKey: coalesceKey);
  }

  void addLayer(MemeLayer layer) {
    if (_document.layers.length >= 100) {
      throw StateError('A meme can have up to 100 layers.');
    }
    apply(_document.copyWith(layers: [..._document.layers, layer]));
    selectLayer(layer.id);
  }

  void deleteLayer(String id) {
    final layer = _find(id);
    if (layer == null || layer.locked) return;
    apply(_document.copyWith(
        layers: _document.layers.where((layer) => layer.id != id).toList()));
  }

  void duplicateLayer(String id) {
    final layer = _find(id);
    if (layer == null) return;
    addLayer(layer.copyWith(
      id: newMemeId(),
      role: null,
      x: min(layer.x + .025, 1 - layer.width),
      y: min(layer.y + .025, 1 - layer.height),
      locked: false,
    ));
  }

  void reorderLayer(String id, int newIndex) {
    final layer = _find(id);
    if (layer == null || layer.locked) return;
    final layers = [..._document.layers]..remove(layer);
    layers.insert(newIndex.clamp(0, layers.length), layer);
    apply(_document.copyWith(layers: layers));
  }

  /// Fit reflow keeps artwork centered and all layer boxes within the canvas.
  /// The UI confirms destructive layout changes before invoking this method.
  void setLayout(MemeLayout layout) {
    if (layout == _document.layout) return;
    final previousHeight = _document.pixelHeight.toDouble();
    final nextHeight = layout.pixelHeight.toDouble();
    final factor = previousHeight / nextHeight;
    final captions = _captionLayers;
    final layers = _document.layers.map((layer) {
      final captionIndex =
          captions.indexWhere((caption) => caption?.id == layer.id);
      if (captionIndex != -1 && layout == MemeLayout.twoPanel) {
        return layer.copyWith(
            x: captionIndex == 0 ? .025 : .525, y: .06, width: .45, height: .2);
      }
      if (captionIndex != -1 && _document.layout == MemeLayout.twoPanel) {
        final height = .17 * 1080 / nextHeight;
        return layer.copyWith(
            x: .06,
            width: .88,
            height: height,
            y: captionIndex == 0
                ? .038 * 1080 / nextHeight
                : 1 - .064 * 1080 / nextHeight - height);
      }
      final height = (layer.height * factor).clamp(.01, 1.0);
      // Keep captions at their respective edges, subject layers at the center.
      final double y;
      if (layer.type == MemeLayerType.text && layer.y < .25) {
        y = (layer.y * factor).clamp(0.0, 1 - height);
      } else if (layer.type == MemeLayerType.text && layer.y > .6) {
        y = (1 - (1 - layer.y - layer.height) * factor - height)
            .clamp(0.0, 1 - height);
      } else {
        y = (.5 + (layer.y + layer.height / 2 - .5) * factor - height / 2)
            .clamp(0.0, 1 - height);
      }
      return layer.copyWith(y: y, height: height);
    }).toList();
    apply(_document.copyWith(
      layout: layout,
      layers: layers,
      background: _document.background.copyWith(fit: 'contain'),
    ));
  }

  /// Replaces only the existing two caption layers; decorations are preserved.
  void setCaptions(MemeCaptionPair pair) {
    if (!canReplaceCaptions) {
      throw StateError(
          'Unlock the caption layers in Layers before replacing this pair.');
    }
    final textLayers = _captionLayers;
    final layers = [..._document.layers];
    for (var i = 0; i < 2; i++) {
      final text = i == 0 ? pair.top : pair.bottom;
      final original = textLayers[i];
      if (original != null) {
        final index = layers.indexWhere((layer) => layer.id == original.id);
        layers[index] = original.copyWith(text: text);
      } else {
        layers.add(MemeLayer(
            id: newMemeId(),
            type: MemeLayerType.text,
            y: i == 0 ? .04 : .76,
            role: i == 0 ? 'top' : 'bottom',
            text: text));
      }
    }
    apply(_document.copyWith(layers: layers, captionId: pair.id));
  }

  void setVisualStyle(String style) {
    final textStyle = switch (style) {
      'epic' => const MemeTextStyle(
          color: 0xff172c42,
          strokeColor: 0xffffffff,
          strokeWidth: .002,
          shadow: true,
          uppercase: true),
      'cute' => const MemeTextStyle(
          color: 0xff172c42, pillColor: 0x99f9b4cb, fontWeight: 800),
      'sarcastic' => const MemeTextStyle(
          fontFamily: 'MemeMono',
          color: 0xff172c42,
          fontSize: .044,
          fontWeight: 700),
      'cozy' => const MemeTextStyle(
          color: 0xff473b32,
          pillColor: 0xddf5e4c9,
          fontWeight: 700,
          lineHeight: 1.2),
      'retro' => const MemeTextStyle(
          fontFamily: 'MemeMono',
          color: 0xff246372,
          strokeColor: 0xffffd55c,
          strokeWidth: .0015,
          fontSize: .044,
          fontWeight: 700),
      _ => throw ArgumentError.value(style, 'style'),
    };
    apply(_document.copyWith(visualStyle: style, layers: [
      for (final layer in _document.layers)
        layer.type == MemeLayerType.text && !layer.locked
            ? layer.copyWith(textStyle: textStyle)
            : layer,
    ]));
  }

  MemeLayer? _find(String id) {
    for (final layer in _document.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  List<MemeLayer?> get _captionLayers {
    return [_findCaption('top'), _findCaption('bottom')];
  }

  MemeLayer? _findCaption(String role) {
    for (final layer in _document.layers) {
      if (layer.type == MemeLayerType.text && layer.role == role) return layer;
    }
    return null;
  }

  void _checkSelection() {
    if (_selectedLayerId != null && _find(_selectedLayerId!) == null) {
      _selectedLayerId = null;
    }
  }

  static String _fingerprint(MemeDocument document) =>
      jsonEncode(document.toJson()..remove('updatedAt'));
}
