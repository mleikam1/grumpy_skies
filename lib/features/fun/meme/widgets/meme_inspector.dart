import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../meme_catalog.dart';
import '../meme_editor_controller.dart';
import '../meme_weather.dart';
import '../models/meme_document.dart';

const memeInk = Color(0xff172c42);
const memeCream = Color(0xfffff8ec);
String newLayerId() => 'layer_${DateTime.now().microsecondsSinceEpoch}';

class MemeInspector extends StatelessWidget {
  const MemeInspector(
      {super.key,
      required this.editor,
      required this.catalog,
      required this.section,
      required this.onPhoto,
      required this.onRoast,
      required this.onReroll,
      required this.onUpdateWeather});
  final MemeEditorController editor;
  final MemeCatalog catalog;
  final String section;
  final VoidCallback onPhoto, onRoast, onReroll;
  final void Function(bool includeCity) onUpdateWeather;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: editor,
      builder: (context, _) {
        final l = editor.selectedLayer;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(section, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...switch (section) {
            'Text' => _text(context, l),
            'Stickers' => _stickers(),
            'Layers' => _layers(context, l),
            'Canvas' => _canvas(context),
            'Weather' => _weather(),
            _ => _text(context, l),
          },
          const SizedBox(height: 32),
        ]);
      });

  List<Widget> _text(BuildContext context, MemeLayer? l) => [
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () => editor.addLayer(MemeLayer(
                  id: newLayerId(),
                  type: MemeLayerType.text,
                  x: .1,
                  y: .4,
                  width: .8,
                  height: .15,
                  text: 'A little weather drama')),
              icon: const Icon(Icons.add),
              label: const Text('Add text')),
          OutlinedButton(
              onPressed: onReroll, child: const Text('Reroll Caption')),
          OutlinedButton(
              onPressed: onRoast, child: const Text('Use Current Roast')),
        ]),
        const SizedBox(height: 16),
        for (final caption in editor.document.layers.where((x) =>
            x.type == MemeLayerType.text ||
            x.type == MemeLayerType.weatherBadge)) ...[
          CaptionInput(
              key: ValueKey(caption.id),
              label: caption.role == 'top'
                  ? 'Top caption'
                  : caption.role == 'bottom'
                      ? 'Bottom caption'
                      : 'Caption',
              value: caption.text,
              enabled: !caption.locked,
              onFocus: () => editor.selectLayer(caption.id),
              onChanged: (text) => editor.updateLayer(
                  caption.copyWith(text: text),
                  coalesceKey: 'text-${caption.id}')),
          const SizedBox(height: 12),
        ],
        if (l != null &&
            (l.type == MemeLayerType.text ||
                l.type == MemeLayerType.weatherBadge)) ...[
          const Divider(),
          const Text('Selected text style'),
          DropdownButtonFormField<String>(
              initialValue: l.textStyle.fontFamily,
              decoration: const InputDecoration(labelText: 'Font'),
              items: const [
                DropdownMenuItem(
                    value: 'MemeSans', child: Text('DayMaker Sans')),
                DropdownMenuItem(value: 'MemeMono', child: Text('Retro Mono'))
              ],
              onChanged: l.locked
                  ? null
                  : (v) => editor.updateLayer(l.copyWith(
                      textStyle: l.textStyle.copyWith(fontFamily: v)))),
          _slider(
              'Font size',
              l.textStyle.fontSize,
              .015,
              .15,
              (v) => editor.updateLayer(
                  l.copyWith(textStyle: l.textStyle.copyWith(fontSize: v)),
                  coalesceKey: 'font-size'),
              enabled: !l.locked),
          _slider(
              'Line spacing',
              l.textStyle.lineHeight,
              .8,
              2,
              (v) => editor.updateLayer(
                  l.copyWith(textStyle: l.textStyle.copyWith(lineHeight: v)),
                  coalesceKey: 'line-height'),
              enabled: !l.locked),
          const Text('Text color'),
          _colors(
              l.textStyle.color,
              (v) => editor.updateLayer(
                  l.copyWith(textStyle: l.textStyle.copyWith(color: v)))),
          _slider(
              'Outline',
              l.textStyle.strokeWidth,
              0,
              .008,
              (v) => editor.updateLayer(
                  l.copyWith(textStyle: l.textStyle.copyWith(strokeWidth: v)),
                  coalesceKey: 'stroke'),
              enabled: !l.locked),
          const Text('Outline color'),
          _colors(
              l.textStyle.strokeColor,
              (v) => editor.updateLayer(
                  l.copyWith(textStyle: l.textStyle.copyWith(strokeColor: v)))),
          Wrap(children: [
            for (final align in ['left', 'center', 'right'])
              ChoiceChip(
                  label: Text(align),
                  selected: l.textStyle.alignment == align,
                  onSelected: l.locked
                      ? null
                      : (_) => editor.updateLayer(l.copyWith(
                          textStyle: l.textStyle.copyWith(alignment: align))))
          ]),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Uppercase'),
              value: l.textStyle.uppercase,
              onChanged: l.locked
                  ? null
                  : (v) => editor.updateLayer(l.copyWith(
                      textStyle: l.textStyle.copyWith(uppercase: v)))),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shadow'),
              value: l.textStyle.shadow,
              onChanged: l.locked
                  ? null
                  : (v) => editor.updateLayer(
                      l.copyWith(textStyle: l.textStyle.copyWith(shadow: v)))),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Caption pill'),
              value: l.textStyle.pillColor != null,
              onChanged: l.locked
                  ? null
                  : (v) => editor.updateLayer(l.copyWith(
                          textStyle: MemeTextStyle.fromJson({
                        ...l.textStyle.toJson(),
                        'pillColor': v ? 0xfffde1eb : null
                      })))),
        ],
      ];

  List<Widget> _stickers() => [
        const Text('24 little weather troublemakers. Tap to add.'),
        const SizedBox(height: 12),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: catalog.stickers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 112,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8),
            itemBuilder: (context, i) {
              final s = catalog.stickers[i];
              return Material(
                  color: const Color(0xffedf2ed),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => editor.addLayer(MemeLayer(
                          id: newLayerId(),
                          type: MemeLayerType.sticker,
                          x: .35,
                          y: .35,
                          width: .3,
                          height: .3 * editor.document.layout.aspectRatio,
                          assetRef: s.assetPath)),
                      child: Column(children: [
                        Expanded(
                            child: Image.asset(s.assetPath, cacheWidth: 160)),
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(s.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: memeInk, fontSize: 11)))
                      ])));
            }),
      ];

  List<Widget> _layers(BuildContext context, MemeLayer? l) => [
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: onPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Photo layer')),
          for (final shape in ['rectangle', 'ellipse'])
            OutlinedButton(
                onPressed: () => editor.addLayer(MemeLayer(
                    id: newLayerId(),
                    type: MemeLayerType.shape,
                    x: .25,
                    y: .3,
                    width: .4,
                    height: .3,
                    color: 0xffffd76a,
                    shape: shape)),
                child: Text('Add $shape')),
        ]),
        const SizedBox(height: 12),
        for (final layer in editor.document.layers.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: layer.id == l?.id,
            leading: Icon(layer.hidden
                ? Icons.visibility_off_outlined
                : layer.type == MemeLayerType.text
                    ? Icons.text_fields
                    : Icons.layers_outlined),
            title: Text(layer.text.isEmpty ? layer.type.name : layer.text,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: layer.locked ? const Text('Locked') : null,
            onTap: () => editor.selectLayer(layer.id),
          ),
        if (l != null) ...[
          const Divider(),
          Wrap(spacing: 4, runSpacing: 4, children: [
            _action('Duplicate', Icons.copy, () => editor.duplicateLayer(l.id)),
            _action('Delete', Icons.delete_outline,
                l.locked ? null : () => editor.deleteLayer(l.id)),
            _action(
                l.locked ? 'Unlock' : 'Lock',
                l.locked ? Icons.lock_open : Icons.lock,
                () => editor.updateLayer(l.copyWith(locked: !l.locked))),
            _action(
                l.hidden ? 'Show' : 'Hide',
                l.hidden ? Icons.visibility : Icons.visibility_off,
                () => editor.updateLayer(l.copyWith(hidden: !l.hidden))),
            _action(
                'Move forward',
                Icons.flip_to_front,
                l.locked
                    ? null
                    : () => editor.reorderLayer(
                        l.id,
                        (editor.document.layers.indexOf(l) + 1)
                            .clamp(0, editor.document.layers.length - 1))),
            _action(
                'Move backward',
                Icons.flip_to_back,
                l.locked
                    ? null
                    : () => editor.reorderLayer(
                        l.id,
                        (editor.document.layers.indexOf(l) - 1)
                            .clamp(0, editor.document.layers.length - 1))),
            _action(
                'Center horizontally',
                Icons.align_horizontal_center,
                l.locked
                    ? null
                    : () =>
                        editor.updateLayer(l.copyWith(x: (1 - l.width) / 2))),
            _action(
                'Center vertically',
                Icons.align_vertical_center,
                l.locked
                    ? null
                    : () =>
                        editor.updateLayer(l.copyWith(y: (1 - l.height) / 2))),
          ]),
          _slider('Horizontal position', l.x, 0, 1 - l.width,
              (v) => editor.updateLayer(l.copyWith(x: v), coalesceKey: 'x'),
              enabled: !l.locked),
          _slider('Vertical position', l.y, 0, 1 - l.height,
              (v) => editor.updateLayer(l.copyWith(y: v), coalesceKey: 'y'),
              enabled: !l.locked),
          _slider(
              'Width',
              l.width,
              .035,
              1 - l.x,
              (v) => editor.updateLayer(l.copyWith(width: v),
                  coalesceKey: 'width'),
              enabled: !l.locked),
          _slider(
              'Height',
              l.height,
              .035,
              1 - l.y,
              (v) => editor.updateLayer(l.copyWith(height: v),
                  coalesceKey: 'height'),
              enabled: !l.locked),
          _slider(
              'Rotate',
              l.rotation,
              -math.pi,
              math.pi,
              (v) => editor.updateLayer(l.copyWith(rotation: v),
                  coalesceKey: 'rotation'),
              enabled: !l.locked),
          if (l.type == MemeLayerType.shape)
            _colors(l.color, (v) => editor.updateLayer(l.copyWith(color: v))),
          if (l.type == MemeLayerType.image) ...[
            const Text('Photo crop and adjustments'),
            _slider(
                'Photo zoom',
                l.zoom,
                1,
                5,
                (v) => editor.updateLayer(l.copyWith(zoom: v),
                    coalesceKey: 'photo-zoom')),
            _slider(
                'Photo pan X',
                l.panX,
                -1,
                1,
                (v) => editor.updateLayer(l.copyWith(panX: v),
                    coalesceKey: 'photo-x')),
            _slider(
                'Photo pan Y',
                l.panY,
                -1,
                1,
                (v) => editor.updateLayer(l.copyWith(panY: v),
                    coalesceKey: 'photo-y')),
            _slider(
                'Brightness',
                l.brightness,
                -.5,
                .5,
                (v) => editor.updateLayer(l.copyWith(brightness: v),
                    coalesceKey: 'brightness')),
            _slider(
                'Contrast',
                l.contrast,
                .5,
                2,
                (v) => editor.updateLayer(l.copyWith(contrast: v),
                    coalesceKey: 'contrast')),
            Wrap(children: [
              _action('Flip horizontal', Icons.flip,
                  () => editor.updateLayer(l.copyWith(flipX: !l.flipX))),
              _action('Flip vertical', Icons.flip_camera_android,
                  () => editor.updateLayer(l.copyWith(flipY: !l.flipY)))
            ]),
          ],
        ] else
          const Text('Select a layer to move, resize, rotate, or reorder it.'),
      ];

  List<Widget> _canvas(BuildContext context) {
    final d = editor.document, b = d.background;
    return [
      DropdownButtonFormField<String>(
          initialValue: d.templateId ?? 'custom',
          isExpanded: true,
          key: ValueKey('artwork-${d.templateId}'),
          decoration: const InputDecoration(labelText: 'Template artwork'),
          items: [
            const DropdownMenuItem(
                value: 'custom', child: Text('Custom / blank')),
            for (final t in catalog.templates)
              DropdownMenuItem(value: t.id, child: Text(t.name))
          ],
          onChanged: (id) async {
            if (id == null || id == d.templateId) return;
            final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                        title: const Text('Change the artwork?'),
                        content: const Text(
                            'Your captions and other layers stay editable. You can undo the background change.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Keep artwork')),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Change artwork'))
                        ]));
            if (confirmed != true) return;
            final template = catalog.templateById(id);
            editor.apply(editor.document.copyWith(
                templateId: template?.id,
                background: MemeBackground(assetRef: template?.assetPath)));
          }),
      const SizedBox(height: 16),
      const Text('Layout • artwork stays centered and fitted'),
      Wrap(spacing: 8, children: [
        for (final layout in MemeLayout.values)
          ChoiceChip(
              label: Text(switch (layout) {
                MemeLayout.square => 'Square 1:1',
                MemeLayout.portrait => 'Portrait 4:5',
                MemeLayout.story => 'Story 9:16',
                MemeLayout.twoPanel => 'Two panels'
              }),
              selected: d.layout == layout,
              onSelected: (_) async {
                if (layout == d.layout) return;
                final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                            title: const Text('Change the layout?'),
                            content: const Text(
                                'Artwork will fit the new canvas. Captions and layers will reflow. You can undo this change.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Keep layout')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Change layout'))
                            ]));
                if (ok == true) editor.setLayout(layout);
              })
      ]),
      const SizedBox(height: 16),
      const Text('Visual style • separate from persona'),
      Wrap(spacing: 8, children: [
        for (final style in ['epic', 'cute', 'sarcastic', 'cozy', 'retro'])
          ChoiceChip(
              label: Text('${style[0].toUpperCase()}${style.substring(1)}'),
              selected: d.visualStyle == style,
              onSelected: (_) => editor.setVisualStyle(style))
      ]),
      const SizedBox(height: 16),
      const Text('Canvas fill'),
      _colors(
          b.color,
          (color) =>
              editor.apply(d.copyWith(background: b.copyWith(color: color)))),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('DayMaker watermark'),
          value: d.watermark,
          onChanged: (v) => editor.apply(d.copyWith(watermark: v))),
      if (b.assetRef != null && !b.assetRef!.startsWith('assets/')) ...[
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Crop photo to fill'),
            value: b.fit == 'cover',
            onChanged: (v) => editor.apply(d.copyWith(
                background: b.copyWith(fit: v ? 'cover' : 'contain')))),
        _slider(
            'Photo zoom',
            b.zoom,
            1,
            5,
            (v) => editor.apply(d.copyWith(background: b.copyWith(zoom: v)),
                coalesceKey: 'bg-zoom')),
        _slider(
            'Photo pan X',
            b.panX,
            -1,
            1,
            (v) => editor.apply(d.copyWith(background: b.copyWith(panX: v)),
                coalesceKey: 'bg-x')),
        _slider(
            'Photo pan Y',
            b.panY,
            -1,
            1,
            (v) => editor.apply(d.copyWith(background: b.copyWith(panY: v)),
                coalesceKey: 'bg-y')),
        _slider(
            'Photo rotation',
            b.rotation,
            -math.pi,
            math.pi,
            (v) => editor.apply(d.copyWith(background: b.copyWith(rotation: v)),
                coalesceKey: 'bg-rotate')),
        _slider(
            'Photo brightness',
            b.brightness,
            -.5,
            .5,
            (v) => editor.apply(
                d.copyWith(background: b.copyWith(brightness: v)),
                coalesceKey: 'bg-brightness')),
        _slider(
            'Photo contrast',
            b.contrast,
            .5,
            2,
            (v) => editor.apply(d.copyWith(background: b.copyWith(contrast: v)),
                coalesceKey: 'bg-contrast')),
        Wrap(children: [
          _action(
              'Flip horizontal',
              Icons.flip,
              () => editor
                  .apply(d.copyWith(background: b.copyWith(flipX: !b.flipX)))),
          _action(
              'Flip vertical',
              Icons.flip_camera_android,
              () => editor
                  .apply(d.copyWith(background: b.copyWith(flipY: !b.flipY))))
        ]),
      ],
    ];
  }

  List<Widget> _weather() {
    final snapshot = editor.document.weatherSnapshot;
    return [
      Text(MemeWeather.statusLabel(snapshot)),
      if (snapshot?['observedAt'] != null)
        Text(
            'Observed ${snapshot!['observedAt']}\n${snapshot['timezone'] ?? 'Timezone unavailable'}'),
      const SizedBox(height: 12),
      const Text(
          'Frozen until you update. Adding a chip makes it part of your exported image.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in MemeWeather.tokens(snapshot).entries)
          ActionChip(
              label: Text('${entry.key}: ${entry.value}'),
              onPressed: () => editor.addLayer(MemeLayer(
                  id: newLayerId(),
                  type: MemeLayerType.weatherBadge,
                  x: .15,
                  y: .65,
                  width: .7,
                  height: .085,
                  text: entry.value,
                  textStyle: const MemeTextStyle(
                      fontSize: .032, pillColor: 0xfffff8ec))))
      ]),
      OutlinedButton(
          onPressed: () => onUpdateWeather(false),
          child: const Text('Update from cached weather')),
      OutlinedButton(
          onPressed: () => onUpdateWeather(true),
          child: const Text('Include city in this meme')),
      const Text(
          'City is excluded until you explicitly include it. No precise location is stored in a meme.'),
    ];
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> changed,
      {bool enabled = true}) {
    final upper = math.max(min + .001, max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text(label),
      Slider(
          value: value.clamp(min, upper),
          min: min,
          max: upper,
          onChanged: enabled ? changed : null,
          semanticFormatterCallback: (v) => v.toStringAsFixed(2))
    ]);
  }

  Widget _action(String label, IconData icon, VoidCallback? callback) =>
      Tooltip(
          message: label,
          child: IconButton(
              onPressed: callback, icon: Icon(icon), tooltip: label));
  Widget _colors(int current, ValueChanged<int> changed) =>
      Wrap(spacing: 4, children: [
        for (final color in [
          0xff172c42,
          0xfffff8ec,
          0xffffd76a,
          0xfff69db7,
          0xff87d1e5,
          0xffa3d9b6,
          0xffbba7ff,
          0xff000000
        ])
          Semantics(
              label: 'Color ${color.toRadixString(16)}',
              selected: current == color,
              button: true,
              child: InkWell(
                  onTap: () => changed(color),
                  child: Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(8),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: current == color
                                      ? Colors.white
                                      : Colors.grey,
                                  width: current == color ? 3 : 1))))))
      ]);
}

class CaptionInput extends StatefulWidget {
  const CaptionInput(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.onFocus,
      this.enabled = true,
      this.maxLength = 1000});
  final String label, value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFocus;
  final bool enabled;
  final int maxLength;
  @override
  State<CaptionInput> createState() => _CaptionInputState();
}

class _CaptionInputState extends State<CaptionInput> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant CaptionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(
              offset: math.min(
                  _controller.selection.baseOffset
                      .clamp(0, widget.value.length),
                  widget.value.length)));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
      controller: _controller,
      enabled: widget.enabled,
      onTap: widget.onFocus,
      onChanged: widget.onChanged,
      minLines: 1,
      maxLines: 5,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          counterText: ''));
}
