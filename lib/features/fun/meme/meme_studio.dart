import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../config/app_routes.dart';
import '../../../design/dm_colors.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/cache_service.dart';
import '../../../services/settings_controller.dart';
import '../../../services/weather_location_controller.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../roasts/models/roast_persona.dart';
import 'meme_catalog.dart';
import 'meme_editor_controller.dart';
import 'meme_suggestions.dart';
import 'meme_weather.dart';
import 'models/meme_document.dart';
import 'platform/meme_import_service.dart';
import 'platform/meme_export_service.dart';
import 'platform/meme_drop_zone.dart';
import 'storage/meme_store.dart';
import 'rendering/meme_renderer.dart';
import 'widgets/meme_document_canvas.dart';
import 'widgets/meme_export_preview.dart';
import 'widgets/meme_inspector.dart';
import 'widgets/meme_library.dart';

class MemeStudio extends StatefulWidget {
  const MemeStudio({super.key, this.initialRoast, this.store, this.exports});
  final DisplayedRoastSnapshot? initialRoast;
  final MemeStore? store;
  final MemeExportService? exports;
  @override
  State<MemeStudio> createState() => _MemeStudioState();
}

class _MemeStudioState extends State<MemeStudio> with WidgetsBindingObserver {
  late final MemeStore _store = widget.store ?? MemeStore.platform();
  late final MemeImportService _imports = MemeImportService(_store);
  late final MemeExportService _exports = widget.exports ?? MemeExportService();
  late final MemeImageCache _images =
      MemeImageCache((ref) => _store.getMedia(ref.replaceFirst('media:', '')));
  MemeCatalog? _catalog;
  MemeEditorController? _editor;
  List<MemeDocument> _drafts = [];
  Set<String> _favorites = {};
  List<String> _recent = [];
  List<Map<String, dynamic>> _exportRecords = [];
  Timer? _autosave;
  int _lastRevision = -1;
  bool _busy = false, _customize = false;
  bool _openedFromSavedProject = false;
  String _section = 'Text';
  String? _error;
  String _saveStatus = 'Saved locally';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final catalog = await MemeCatalog.load();
      await loadMemeFonts();
      if (!mounted) return;
      setState(() => _catalog = catalog);
      await _reloadLibrary();
      try {
        final recovered = await _imports.recoverLostImages();
        for (final photo in recovered) {
          final d = MemeDocument.blank(name: 'Recovered photo').copyWith(
              background:
                  MemeBackground(assetRef: photo.assetRef, fit: 'contain'));
          await _store.save(d);
        }
        if (recovered.isNotEmpty) {
          await _reloadLibrary();
          _notice(
              'Recovered ${recovered.length} photo draft(s) after the picker closed.');
        }
      } catch (error) {
        if (mounted) setState(() => _error = 'Photo recovery: $error');
      }
      if (widget.initialRoast != null && mounted) {
        final t = MemeSuggestions.chooseTemplate(
                catalog: catalog,
                weatherSnapshot: widget.initialRoast!.weatherSnapshot) ??
            catalog.templates.first;
        _open(t.createDocument());
        _applyRoast(widget.initialRoast!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the studio: $e');
    }
  }

  Future<void> _reloadLibrary() async {
    try {
      final drafts = await _store.listDocuments(),
          favorites = await _store.favorites();
      final recent = await _store.recentCaptionIds(),
          metadata = await _store.readMetadata();
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _favorites = favorites;
          _recent = recent;
          _exportRecords = (metadata['exports'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (_store.recoveryIssues.isNotEmpty) {
            _error = _store.recoveryIssues.join('\n');
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Local storage is unavailable: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    final d = _editor?.document;
    if (d != null) unawaited(_store.save(d).catchError((Object _) {}));
    _editor?.removeListener(_changed);
    _editor?.dispose();
    _images.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message,
          {String actionLabel = 'Replace'}) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep editing')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(actionLabel))
              ])) ??
      false;
  void _open(MemeDocument d, {bool fromSavedProject = false}) {
    _autosave?.cancel();
    _editor?.removeListener(_changed);
    _editor?.dispose();
    _editor = MemeEditorController(d)..addListener(_changed);
    _openedFromSavedProject = fromSavedProject;
    _lastRevision = -1;
    setState(() {
      _customize = false;
      _saveStatus = 'Saving…';
    });
    _changed();
  }

  void _changed() {
    final e = _editor;
    if (e == null || e.revision == _lastRevision) return;
    _lastRevision = e.revision;
    unawaited(_images.prepare(e.document));
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 650), () => _save());
    if (mounted) setState(() => _saveStatus = 'Saving…');
  }

  Future<bool> _save({bool announce = false}) async {
    final e = _editor;
    if (e == null) return true;
    _autosave?.cancel();
    final d = e.document;
    try {
      await _store.save(d);
      if (mounted && identical(e, _editor)) {
        e.markSaved(document: d);
        setState(() => _saveStatus = e.isDirty ? 'Saving…' : 'Saved locally');
      }
      if (announce) _notice('Draft saved on this device.');
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveStatus = 'Not saved';
          _error = error.toString();
        });
      }
      return false;
    }
  }

  Map<String, dynamic>? _weather({bool includeCity = false}) {
    final unit = context.read<SettingsController?>()?.temperatureUnit ??
        TemperatureUnit.fahrenheit;
    final cache = context.read<CacheService?>(),
        locations = context.read<WeatherLocationController?>();
    if (cache != null && locations != null) {
      return MemeWeather.fromCache(cache, locations,
          temperatureUnit: unit, includeCity: includeCity);
    }
    final bundle = context.read<DisplayedRoastRegistry?>()?.cachedWeather;
    return bundle == null
        ? null
        : MemeWeather.freeze(bundle,
            temperatureUnit: unit, includeCity: includeCity);
  }

  Future<void> _template(MemeTemplate t) async {
    _open(t.createDocument());
    await _store.rememberCaption(t.defaultCaption.id);
    await _store.rememberCaption(t.id);
    _recent = await _store.recentCaptionIds();
  }

  Future<void> _createToday() async {
    final weather = _weather();
    final t = MemeSuggestions.chooseTemplate(
        catalog: _catalog!, weatherSnapshot: weather, recentIds: _recent);
    if (t == null) {
      _notice(weather == null
          ? 'No cached forecast yet. Choose any template below.'
          : 'No matching weather template. Choose any template below.');
      return;
    }
    _open(t.createDocument(weatherSnapshot: weather));
    await _store.rememberCaption(t.defaultCaption.id);
    await _store.rememberCaption(t.id);
    _recent = await _store.recentCaptionIds();
  }

  Future<void> _surprise() async {
    if (_editor != null &&
        (_openedFromSavedProject || _editor!.hasUserEdits) &&
        !await _confirm('Surprise me?',
            'This replaces your current artwork and captions. Your current draft will be kept in My Memes.')) {
      return;
    }
    if (_editor != null && !await _save()) return;
    if (!mounted) return;
    final t = MemeSuggestions.chooseTemplate(
        catalog: _catalog!, recentIds: _recent, surprise: true)!;
    await _template(t);
  }

  Future<void> _photo({bool layer = false, bool camera = false}) async {
    final photo = await _imports.pick(camera: camera);
    if (photo == null || !mounted) return;
    _addPhoto(photo, layer: layer);
  }

  void _addPhoto(ImportedMemePhoto photo, {bool layer = false}) {
    if (layer && _editor != null) {
      _editor!.addLayer(MemeLayer(
          id: newLayerId(),
          type: MemeLayerType.image,
          x: .15,
          y: .25,
          width: .7,
          height: .4,
          assetRef: photo.assetRef));
    } else {
      _open(MemeDocument.blank(name: 'My photo forecast').copyWith(
          background:
              MemeBackground(assetRef: photo.assetRef, fit: 'contain')));
    }
  }

  Future<void> _reroll() async {
    final e = _editor!,
        t = _catalog!.templateById(_editor!.document.templateId ?? '');
    if (t == null) {
      _notice(
          'Choose a weather template to use its matching caption suggestions.');
      return;
    }
    if (!e.canReplaceCaptions) {
      _notice(
          'Unlock the caption layers in Layers before replacing this pair.');
      return;
    }
    if ((_openedFromSavedProject || e.hasUserEdits) &&
        !await _confirm('Reroll the captions?',
            'Only the caption pair will change. Your artwork and other layers stay in place.')) {
      return;
    }
    if (!mounted || !identical(e, _editor)) return;
    final pair = MemeSuggestions.captionFor(
        catalog: _catalog!,
        template: t,
        personaId: e.document.personaId,
        weatherSnapshot: e.document.weatherSnapshot,
        recentIds: _recent);
    e.setCaptions(pair);
    await _store.rememberCaption(pair.id);
    _recent = await _store.recentCaptionIds();
    if (mounted && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  Future<void> _currentRoast() async {
    final e = _editor;
    if (e == null) return;
    if (!e.canReplaceCaptions) {
      _notice(
          'Unlock the caption layers in Layers before replacing this pair.');
      return;
    }
    final choices = context.read<DisplayedRoastRegistry?>()?.choices ??
        [if (widget.initialRoast != null) widget.initialRoast!];
    if (choices.isEmpty) {
      _notice(
          'Open Home or Roasts and use Share to Meme to copy the exact displayed roast.');
      return;
    }
    final choice = await showDialog<DisplayedRoastSnapshot>(
        context: context,
        builder: (c) => SimpleDialog(
                title: const Text('Choose the displayed roast'),
                children: [
                  for (final r in choices)
                    SimpleDialogOption(
                        onPressed: () => Navigator.pop(c, r),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.chooserLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(r.text)
                            ]))
                ]));
    if (choice == null || !mounted || !identical(e, _editor)) return;
    if ((_openedFromSavedProject || e.hasUserEdits) &&
        !await _confirm('Use this roast?',
            'This replaces the caption text with the exact roast you selected.')) {
      return;
    }
    if (!mounted || !identical(e, _editor)) return;
    _applyRoast(choice);
  }

  void _applyRoast(DisplayedRoastSnapshot roast) {
    final e = _editor!;
    e.beginGesture();
    try {
      e.setCaptions(MemeCaptionPair(
          id: roast.id,
          top: roast.isSample ? 'SAMPLE WEATHER ROAST' : "TODAY’S FORECAST",
          bottom: roast.text,
          personaId: roast.personaId));
      e.apply(e.document.copyWith(
          personaId: roast.personaId, weatherSnapshot: roast.weatherSnapshot));
    } finally {
      e.endGesture();
    }
  }

  Future<void> _updateWeather(bool city) async {
    if (city &&
        !await _confirm('Include your city?',
            'Your city name will be available as a chip in this project. It will only appear in the image if you add that chip.',
            actionLabel: 'Include city')) {
      return;
    }
    if (!mounted) return;
    final snapshot = _weather(includeCity: city);
    if (snapshot == null) {
      _notice(
          'No cached weather is available. Your current meme is unchanged.');
      return;
    }
    _editor!.apply(_editor!.document.copyWith(weatherSnapshot: snapshot));
  }

  Future<void> _export() async {
    await _save();
    final d = _editor!.document;
    final png = await exportMemePng(d, _images);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MemeExportPreview(
            document: d, png: png, exports: _exports, store: _store)));
  }

  Future<void> _back() async {
    if (_editor != null) {
      if (!await _save() || !mounted) return;
      _editor!.removeListener(_changed);
      _editor!.dispose();
      setState(() => _editor = null);
      await _reloadLibrary();
      await _store.collectUnreferencedMedia({});
    } else if (mounted) {
      context.go(AppRoutes.fun);
    }
  }

  Future<void> _delete(MemeDocument d) async {
    if (!await _confirm('Delete this draft?',
        '${d.name} will be removed from this device. Exported images and backups are unaffected.',
        actionLabel: 'Delete draft')) {
      return;
    }
    await _store.delete(d.id);
    await _reloadLibrary();
    await _store.collectUnreferencedMedia(_editor?.mediaIds ?? {});
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _editor == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: DmResponsiveScaffold(
        appBar: DmHeaderBar(
            title: 'DayMaker',
            subtitle: 'Weather Meme Studio',
            onBackPressed: () => _guard(_back),
            actions: [
              if (_busy)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))
            ]),
        resizeToAvoidBottomInset: true,
        extendBody: false,
        backgroundGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DMColors.deepNavy,
              DMColors.twilightNavy,
              Color(0xff4a3868)
            ]),
        bodyBuilder: (context, breakpoint) => Column(children: [
          if (_error != null)
            ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: ((MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom -
                                180) *
                            .3)
                        .clamp(60.0, 150.0)),
                child: SingleChildScrollView(
                    child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        color: const Color(0xff542b3f),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Semantics(
                                      liveRegion: true, child: Text(_error!))),
                              IconButton(
                                  tooltip: 'Dismiss message',
                                  onPressed: () =>
                                      setState(() => _error = null),
                                  icon: const Icon(Icons.close))
                            ])))),
          Expanded(
              child: _catalog == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : FilledButton(
                              onPressed: _initialize,
                              child: const Text('Try loading again')))
                  : MemeDropZone(
                      enabled: !_busy,
                      onBytes: (bytes) => _guard(() async {
                            final photo = await _imports.importBytes(bytes);
                            _addPhoto(photo, layer: _editor != null);
                          }),
                      onError: (message) => setState(() => _error = message),
                      child: _editor == null ? _library() : _editing())),
        ]),
      ));
  Widget _library() => MemeLibrary(
        catalog: _catalog!,
        drafts: _drafts,
        favorites: _favorites,
        exports: _exportRecords,
        canCamera: _imports.supportsCamera,
        onTemplate: (t) => _guard(() => _template(t)),
        onDraft: (d) => _open(d, fromSavedProject: true),
        onFavorite: (id) => _guard(() async {
          await _store.setFavorite(id, !_favorites.contains(id));
          await _reloadLibrary();
        }),
        onDelete: (d) => _guard(() => _delete(d)),
        onRemix: (d) => _open(
            d.copyWith(
                id: newMemeId(),
                name: '${d.name} remix',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
            fromSavedProject: true),
        onToday: () => _guard(_createToday),
        onSurprise: () => _guard(_surprise),
        onPhoto: () => _guard(() => _photo()),
        onCamera: () => _guard(() => _photo(camera: true)),
        onBlank: () => _open(MemeDocument.blank()),
        onImportBackup: () => _guard(() async {
          final d = await _imports.pickProjectBackup();
          if (d != null) _open(d, fromSavedProject: true);
        }),
      );
  Widget _editing() => AnimatedBuilder(
      animation: _editor!,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
            final e = _editor!, d = e.document, wide = c.maxWidth >= 850;
            final toolbar = Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(children: [
                    IconButton(
                        onPressed: e.canUndo ? e.undo : null,
                        tooltip: 'Undo',
                        icon: const Icon(Icons.undo)),
                    IconButton(
                        onPressed: e.canRedo ? e.redo : null,
                        tooltip: 'Redo',
                        icon: const Icon(Icons.redo))
                  ]),
                  Text(_saveStatus, style: const TextStyle(fontSize: 12)),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                        onPressed: () => _save(announce: true),
                        child: const Text('Save Draft')),
                    FilledButton.icon(
                        onPressed: _busy ? null : () => _guard(_export),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Export'))
                  ]),
                ]);
            final canvas = Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: wide ? 640 : 600,
                        maxHeight:
                            wide ? (c.maxHeight - 150).clamp(200, 850) : 500),
                    child: MemeDocumentCanvas(editor: e, cache: _images)));
            final tools = Wrap(spacing: 6, runSpacing: 6, children: [
              for (final section in [
                'Text',
                'Stickers',
                'Layers',
                'Canvas',
                'Weather'
              ])
                ChoiceChip(
                    label: Text(section),
                    selected: _customize && _section == section,
                    onSelected: (_) {
                      setState(() {
                        _section = section;
                        _customize = true;
                      });
                      if (!wide) _openTools(section);
                    })
            ]);
            final info =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CaptionInput(
                  label: 'Project name',
                  maxLength: 160,
                  value: d.name,
                  onChanged: (name) => e.apply(
                      d.copyWith(name: name.isEmpty ? 'Untitled' : name),
                      coalesceKey: 'name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                  initialValue: d.personaId ?? 'neutral',
                  key: ValueKey(d.personaId),
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Speaking persona'),
                  items: [
                    const DropdownMenuItem(
                        value: 'neutral', child: Text('Original caption')),
                    for (final p in RoastPersonaId.values)
                      DropdownMenuItem(
                          value: p.storageId,
                          child:
                              Text(RoastPersonas.byId(p.storageId).displayName))
                  ],
                  onChanged: (v) => e
                      .apply(d.copyWith(personaId: v == 'neutral' ? null : v))),
              const SizedBox(height: 12),
              if (wide) tools,
            ]);
            final body = wide
                ? Column(children: [
                    toolbar,
                    const SizedBox(height: 12),
                    Expanded(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Expanded(
                              flex: 6,
                              child: Column(children: [
                                Expanded(child: canvas),
                                const SizedBox(height: 12),
                                const Text(
                                    'Drag to move • pinch to size and rotate • inspector for precise controls')
                              ])),
                          const SizedBox(width: 20),
                          Expanded(
                              flex: 4,
                              child: Column(children: [
                                info,
                                const SizedBox(height: 8),
                                Expanded(
                                    child: _inspector(
                                        _customize ? _section : 'Text'))
                              ]))
                        ]))
                  ])
                : ListView(children: [
                    toolbar,
                    const SizedBox(height: 12),
                    canvas,
                    const SizedBox(height: 14),
                    Text(d.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final l in d.layers
                        .where((l) => l.type == MemeLayerType.text)
                        .take(2))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CaptionInput(
                              key: ValueKey('quick-${l.id}'),
                              label: l.role == 'top'
                                  ? 'Top caption'
                                  : 'Bottom caption',
                              value: l.text,
                              enabled: !l.locked,
                              onChanged: (text) => e.updateLayer(
                                  l.copyWith(text: text),
                                  coalesceKey: 'text-${l.id}'))),
                    tools,
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                        onPressed: () => _openTools('Canvas'),
                        icon: const Icon(Icons.tune),
                        label: const Text('Customize')),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () => _guard(_reroll),
                        child: const Text('Reroll Caption')),
                    TextButton(
                        onPressed: () => _guard(_surprise),
                        child: const Text('Surprise Me')),
                    info,
                    const SizedBox(height: 24),
                  ]);
            return Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent ||
                      FocusManager.instance.primaryFocus?.context?.widget
                          is EditableText) {
                    return KeyEventResult.ignored;
                  }
                  if (FocusManager.instance.primaryFocus?.context
                          ?.findAncestorWidgetOfExactType<EditableText>() !=
                      null) {
                    return KeyEventResult.ignored;
                  }
                  final ctrl = HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed;
                  if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
                    HardwareKeyboard.instance.isShiftPressed
                        ? e.redo()
                        : e.undo();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: body);
          }));
  Widget _inspector(String section) => MemeInspector(
      editor: _editor!,
      catalog: _catalog!,
      section: section,
      onPhoto: () => _guard(() => _photo(layer: true)),
      onRoast: () => _guard(_currentRoast),
      onReroll: () => _guard(_reroll),
      onUpdateWeather: (city) => _guard(() => _updateWeather(city)));
  void _openTools(String section) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (c) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
            child: SizedBox(
                height: MediaQuery.sizeOf(c).height * .7,
                child: _inspector(section))));
  }
}
