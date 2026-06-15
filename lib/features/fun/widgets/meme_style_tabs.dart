import 'package:flutter/material.dart';

import '../../../shared/widgets/dm_segmented_control.dart';
import 'meme_style.dart';

class MemeStyleTabs extends StatelessWidget {
  const MemeStyleTabs({
    super.key,
    required this.selectedStyle,
    required this.onChanged,
    required this.compact,
  });

  final MemeVisualStyle selectedStyle;
  final ValueChanged<MemeVisualStyle> onChanged;
  final bool compact;

  static final _segments = [
    for (final style in MemeVisualStyle.values)
      DmSegment<MemeVisualStyle>(
        value: style,
        label: style.label,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return DmSegmentedControl<MemeVisualStyle>(
      segments: _segments,
      selectedValue: selectedStyle,
      onChanged: onChanged,
      expanded: !compact,
      semanticLabel: 'Meme style tabs',
    );
  }
}
