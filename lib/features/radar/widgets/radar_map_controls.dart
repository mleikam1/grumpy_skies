import 'package:flutter/material.dart';

import '../../../design/dm_spacing.dart';
import '../../../shared/widgets/dm_buttons.dart';

class RadarMapControls extends StatelessWidget {
  const RadarMapControls({
    super.key,
    required this.compact,
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.onLightningChanged,
    required this.onFutureCastChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onLayers,
  });

  final bool compact;
  final bool lightningEnabled;
  final bool futureCastEnabled;
  final ValueChanged<bool> onLightningChanged;
  final ValueChanged<bool> onFutureCastChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      DmIconButton(
        icon: const Icon(Icons.add),
        semanticLabel: 'Zoom in',
        tooltip: 'Zoom in',
        onPressed: onZoomIn,
      ),
      DmIconButton(
        icon: const Icon(Icons.remove),
        semanticLabel: 'Zoom out',
        tooltip: 'Zoom out',
        onPressed: onZoomOut,
      ),
      DmIconButton(
        icon: const Icon(Icons.my_location),
        semanticLabel: 'Use current location',
        tooltip: 'Location',
        onPressed: onLocate,
      ),
      DmIconButton(
        icon: const Icon(Icons.layers_outlined),
        semanticLabel: 'Radar layers',
        tooltip: 'Layers',
        onPressed: onLayers,
      ),
      DmPillButton(
        label: compact
            ? 'Lightning'
            : lightningEnabled
                ? 'Lightning On'
                : 'Lightning Off',
        semanticLabel: lightningEnabled
            ? 'Turn lightning markers off'
            : 'Turn lightning markers on',
        leading: const Icon(Icons.bolt),
        variant: DmPillButtonVariant.glass,
        selected: lightningEnabled,
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.md,
          vertical: DMSpacing.xs,
        ),
        onPressed: () => onLightningChanged(!lightningEnabled),
      ),
      DmPillButton(
        label: compact
            ? 'FutureCast'
            : futureCastEnabled
                ? 'FutureCast On'
                : 'FutureCast Off',
        semanticLabel: futureCastEnabled
            ? 'Turn FutureCast overlay off'
            : 'Turn FutureCast overlay on',
        leading: const Icon(Icons.timeline),
        variant: DmPillButtonVariant.glass,
        selected: futureCastEnabled,
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.md,
          vertical: DMSpacing.xs,
        ),
        onPressed: () => onFutureCastChanged(!futureCastEnabled),
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 320 : 304),
      child: Wrap(
        alignment: WrapAlignment.end,
        runAlignment: WrapAlignment.end,
        spacing: DMSpacing.xs,
        runSpacing: DMSpacing.xs,
        children: controls,
      ),
    );
  }
}
