import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_motion.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';

class DmSegment<T> {
  const DmSegment({
    required this.value,
    required this.label,
    this.icon,
    String? semanticLabel,
  }) : semanticLabel = semanticLabel ?? label;

  final T value;
  final String label;
  final IconData? icon;
  final String semanticLabel;
}

class DmSegmentedControl<T> extends StatelessWidget {
  const DmSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onChanged,
    this.expanded = true,
    this.semanticLabel,
  }) : assert(segments.length > 0);

  final List<DmSegment<T>> segments;
  final T selectedValue;
  final ValueChanged<T>? onChanged;
  final bool expanded;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final segment in segments)
        _DmSegmentTile<T>(
          segment: segment,
          selected: segment.value == selectedValue,
          enabled: onChanged != null,
          onTap: () => onChanged?.call(segment.value),
        ),
    ];

    final row = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final child in children)
          if (expanded) Expanded(child: child) else child,
      ],
    );

    final control = DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.glass,
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.xxs),
        child: expanded
            ? row
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              ),
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: control,
    );
  }
}

class _DmSegmentTile<T> extends StatefulWidget {
  const _DmSegmentTile({
    required this.segment,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DmSegment<T> segment;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_DmSegmentTile<T>> createState() => _DmSegmentTileState<T>();
}

class _DmSegmentTileState<T> extends State<_DmSegmentTile<T>> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final duration = DMMotion.resolve(context, DMMotion.fast);
    final foreground =
        widget.selected ? DMColors.deepNavy : DMColors.textSecondary;
    final background =
        widget.selected ? DMColors.sunriseYellow : Colors.transparent;

    final tile = AnimatedContainer(
      duration: duration,
      curve: DMMotion.easeOut,
      constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.md,
        vertical: DMSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: DMRadius.full,
        border: _focused
            ? Border.all(color: DMColors.sunriseYellow, width: 2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.segment.icon != null) ...[
            Icon(
              widget.segment.icon,
              color: foreground,
              size: DMSpacing.iconMd,
            ),
            const SizedBox(width: DMSpacing.xs),
          ],
          Flexible(
            child: Text(
              widget.segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.label.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.segment.semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            focusColor: DMColors.opacity(DMColors.sunriseYellow, 0.16),
            hoverColor: DMColors.opacity(DMColors.cloudWhite, 0.08),
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: widget.enabled ? widget.onTap : null,
            child: tile,
          ),
        ),
      ),
    );
  }
}
